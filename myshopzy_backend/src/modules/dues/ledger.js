'use strict';

const { randomUUID } = require('node:crypto');

class LedgerError extends Error {
  constructor(status, code, message, details = undefined) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

async function withLedgerTransaction(pool, action) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await action(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      throw new AggregateError(
        [error, rollbackError],
        'The ledger transaction failed and could not be rolled back.',
      );
    }
    throw error;
  } finally {
    client.release();
  }
}

function positiveMinor(value, field = 'amountMinor') {
  let amount;
  try {
    amount = BigInt(value);
  } catch {
    throw new LedgerError(400, 'INVALID_REQUEST', `${field} must be positive integer paise.`);
  }
  if (amount <= 0n || amount > 9223372036854775807n) {
    throw new LedgerError(400, 'INVALID_REQUEST', `${field} must be positive integer paise.`);
  }
  return amount.toString();
}

async function lockCustomer(client, customerUserId) {
  const result = await client.query(
    `SELECT user_id FROM app.customers WHERE user_id = $1 FOR UPDATE`,
    [customerUserId],
  );
  if (result.rows.length !== 1) {
    throw new LedgerError(404, 'CUSTOMER_NOT_FOUND', 'Customer not found.');
  }
}

// Outstanding = confirmed due principal minus recorded payments and waivers.
// Pending-review dues and dispute-note rows never block checkout.
async function getOutstandingMinor(client, customerId) {
  const result = await client.query(
    `SELECT COALESCE(sum(
       CASE
         WHEN entry_type = 'due_confirmed'
           AND evidence->>'kind' = 'confirmation'
           THEN amount_minor
         WHEN entry_type = 'payment_received' THEN -amount_minor
         WHEN entry_type = 'waived'
           AND EXISTS (
             SELECT 1
             FROM app.customer_ledger_entries AS confirmation
             WHERE confirmation.related_entry_id = customer_ledger_entries.related_entry_id
               AND confirmation.entry_type = 'due_confirmed'
               AND confirmation.evidence->>'kind' = 'confirmation'
           )
           THEN -amount_minor
         ELSE 0
       END
     ), 0)::text AS outstanding_minor
     FROM app.customer_ledger_entries
     WHERE customer_user_id = $1`,
    [customerId],
  );
  return BigInt(result.rows[0]?.outstanding_minor ?? '0');
}

// Mutations use the caller's transaction client so ledger and domain changes commit together.
async function createPendingDue(client, {
  customerUserId,
  orderId,
  amountMinor,
  currency,
  reason,
  createdByActor,
  note = null,
  evidence = {},
}) {
  const result = await client.query(
    `INSERT INTO app.customer_ledger_entries (
       id, customer_user_id, order_id, entry_type, amount_minor,
       currency, reason, note, evidence, created_by_actor
     )
     VALUES ($1, $2, $3, 'due_pending_review', $4, $5, $6, $7, $8::jsonb, $9)
     RETURNING id, customer_user_id, order_id, entry_type,
               amount_minor::text AS amount_minor, currency, reason, note,
               evidence, created_by_actor, created_at`,
    [
      randomUUID(),
      customerUserId,
      orderId,
      positiveMinor(amountMinor),
      currency,
      reason,
      note,
      JSON.stringify(evidence),
      createdByActor,
    ],
  );
  return result.rows[0];
}

async function findDueRoot(client, dueEntryId, { lock = false } = {}) {
  const result = await client.query(
    `SELECT id, customer_user_id, order_id, entry_type,
            amount_minor::text AS amount_minor, currency, reason, note
     FROM app.customer_ledger_entries
     WHERE id = $1
       AND entry_type = 'due_pending_review'
       AND related_entry_id IS NULL
     ${lock ? 'FOR UPDATE' : ''}`,
    [dueEntryId],
  );
  return result.rows[0] ?? null;
}

async function confirmDue(client, {
  dueEntryId,
  adminUserId,
  supportReference,
  note = null,
}) {
  const due = await findDueRoot(client, dueEntryId, { lock: true });
  if (!due) {
    throw new LedgerError(404, 'DUE_NOT_FOUND', 'Pending due not found.');
  }
  await lockCustomer(client, due.customer_user_id);
  const previous = await client.query(
    `SELECT id
     FROM app.customer_ledger_entries
     WHERE related_entry_id = $1
       AND evidence->>'kind' IN ('confirmation', 'waiver')
     LIMIT 1`,
    [due.id],
  );
  if (previous.rows.length) {
    throw new LedgerError(409, 'DUE_ALREADY_RESOLVED', 'This due has already been resolved.');
  }
  const result = await client.query(
    `INSERT INTO app.customer_ledger_entries (
       id, customer_user_id, order_id, related_entry_id, entry_type,
       amount_minor, currency, reason, note, evidence, created_by_actor
     )
     VALUES ($1, $2, $3, $4, 'due_confirmed', $5, $6, $7, $8,
             $9::jsonb, $10)
     RETURNING id, related_entry_id, entry_type,
               amount_minor::text AS amount_minor, currency, reason, note,
               evidence, created_by_actor, created_at`,
    [
      randomUUID(),
      due.customer_user_id,
      due.order_id,
      due.id,
      due.amount_minor,
      due.currency,
      due.reason,
      note,
      JSON.stringify({ kind: 'confirmation', supportReference }),
      `admin:${adminUserId}`,
    ],
  );
  return result.rows[0];
}

async function outstandingForDue(client, dueEntryId) {
  const result = await client.query(
    `SELECT COALESCE(sum(
       CASE
         WHEN entry_type = 'due_confirmed'
           AND evidence->>'kind' = 'confirmation' THEN amount_minor
         WHEN entry_type = 'payment_received' OR entry_type = 'waived'
           THEN -amount_minor
         ELSE 0
       END
     ), 0)::text AS outstanding_minor
     FROM app.customer_ledger_entries
     WHERE related_entry_id = $1 OR id = $1`,
    [dueEntryId],
  );
  return BigInt(result.rows[0]?.outstanding_minor ?? '0');
}

async function recordPayment(client, {
  customerUserId,
  amountMinor,
  reference,
  adminUserId,
}) {
  const amount = BigInt(positiveMinor(amountMinor));
  await lockCustomer(client, customerUserId);
  const outstanding = await getOutstandingMinor(client, customerUserId);
  if (amount > outstanding) {
    throw new LedgerError(
      409,
      'OVERPAYMENT',
      "Payment cannot exceed the customer's outstanding balance.",
      { outstandingMinor: outstanding.toString() },
    );
  }

  const dueRows = await client.query(
    `SELECT confirmation.related_entry_id AS due_entry_id,
            confirmation.amount_minor::text AS amount_minor,
            confirmation.currency,
            COALESCE((
              SELECT sum(CASE WHEN e.entry_type IN ('payment_received', 'waived')
                              THEN e.amount_minor ELSE 0 END)
              FROM app.customer_ledger_entries AS e
              WHERE e.related_entry_id = confirmation.related_entry_id
            ), 0)::text AS settled_minor
     FROM app.customer_ledger_entries AS confirmation
     WHERE confirmation.customer_user_id = $1
       AND confirmation.entry_type = 'due_confirmed'
       AND confirmation.evidence->>'kind' = 'confirmation'
     ORDER BY confirmation.created_at, confirmation.id`,
    [customerUserId],
  );

  let remaining = amount;
  const entries = [];
  for (const due of dueRows.rows) {
    const dueOutstanding =
      BigInt(due.amount_minor) - BigInt(due.settled_minor);
    if (dueOutstanding <= 0n) continue;
    const applied = remaining < dueOutstanding ? remaining : dueOutstanding;
    const inserted = await client.query(
      `INSERT INTO app.customer_ledger_entries (
         id, customer_user_id, related_entry_id, entry_type, amount_minor,
         currency, reason, note, evidence, created_by_actor
       )
       VALUES ($1, $2, $3, 'payment_received', $4, $5, 'payment', $6,
               $7::jsonb, $8)
       RETURNING id, related_entry_id, entry_type,
                 amount_minor::text AS amount_minor, currency, note,
                 evidence, created_by_actor, created_at`,
      [
        randomUUID(),
        customerUserId,
        due.due_entry_id,
        applied.toString(),
        due.currency,
        reference,
        JSON.stringify({ kind: 'payment', reference }),
        `admin:${adminUserId}`,
      ],
    );
    entries.push(inserted.rows[0]);
    remaining -= applied;
    if (remaining === 0n) break;
  }
  if (remaining !== 0n) {
    throw new LedgerError(409, 'BALANCE_CHANGED', 'The outstanding balance changed. Retry the payment.');
  }
  return entries;
}

async function waiveDue(client, { dueEntryId, adminUserId, reason }) {
  const due = await findDueRoot(client, dueEntryId, { lock: true });
  if (!due) throw new LedgerError(404, 'DUE_NOT_FOUND', 'Due not found.');
  await lockCustomer(client, due.customer_user_id);
  const events = await client.query(
    `SELECT evidence->>'kind' AS kind
     FROM app.customer_ledger_entries
     WHERE related_entry_id = $1
       AND evidence->>'kind' IN ('confirmation', 'waiver')`,
    [due.id],
  );
  if (events.rows.some((event) => event.kind === 'waiver')) {
    throw new LedgerError(409, 'DUE_ALREADY_RESOLVED', 'This due has already been waived.');
  }
  const confirmed = events.rows.some((event) => event.kind === 'confirmation');
  const remaining = await outstandingForDue(client, due.id);
  if (confirmed && remaining <= 0n) {
    throw new LedgerError(409, 'DUE_ALREADY_RESOLVED', 'This due has already been paid.');
  }
  const amount = confirmed ? remaining : BigInt(due.amount_minor);
  const result = await client.query(
    `INSERT INTO app.customer_ledger_entries (
       id, customer_user_id, order_id, related_entry_id, entry_type,
       amount_minor, currency, reason, note, evidence, created_by_actor
     )
     VALUES ($1, $2, $3, $4, 'waived', $5, $6, $7, $7, $8::jsonb, $9)
     RETURNING id, related_entry_id, entry_type,
               amount_minor::text AS amount_minor, currency, reason, note,
               evidence, created_by_actor, created_at`,
    [
      randomUUID(),
      due.customer_user_id,
      due.order_id,
      due.id,
      amount.toString(),
      due.currency,
      reason,
      JSON.stringify({ kind: 'waiver' }),
      `admin:${adminUserId}`,
    ],
  );
  return result.rows[0];
}

async function addDispute(client, { dueEntryId, customerUserId, message }) {
  const due = await findDueRoot(client, dueEntryId, { lock: true });
  if (!due || due.customer_user_id !== customerUserId) {
    throw new LedgerError(404, 'DUE_NOT_FOUND', 'Due not found.');
  }
  await lockCustomer(client, due.customer_user_id);
  const resolved = await client.query(
    `SELECT id
     FROM app.customer_ledger_entries
     WHERE related_entry_id = $1 AND evidence->>'kind' = 'waiver'
     LIMIT 1`,
    [due.id],
  );
  if (resolved.rows.length) {
    throw new LedgerError(409, 'DUE_ALREADY_RESOLVED', 'This due has already been waived.');
  }
  const confirmed = await client.query(
    `SELECT id FROM app.customer_ledger_entries
     WHERE related_entry_id = $1 AND evidence->>'kind' = 'confirmation' LIMIT 1`,
    [due.id],
  );
  if (
    confirmed.rows.length &&
    (await outstandingForDue(client, due.id)) <= 0n
  ) {
    throw new LedgerError(409, 'DUE_NOT_DISPUTABLE', 'This due is no longer outstanding.');
  }
  const entryType = confirmed.rows.length ? 'due_confirmed' : 'due_pending_review';
  const result = await client.query(
    `INSERT INTO app.customer_ledger_entries (
       id, customer_user_id, order_id, related_entry_id, entry_type,
       amount_minor, currency, reason, note, evidence, created_by_actor
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9,
             $10::jsonb, $11)
     RETURNING id, related_entry_id, entry_type,
               amount_minor::text AS amount_minor, currency, reason, note,
               evidence, created_by_actor, created_at`,
    [
      randomUUID(),
      customerUserId,
      due.order_id,
      due.id,
      entryType,
      due.amount_minor,
      due.currency,
      due.reason,
      message,
      JSON.stringify({ kind: 'dispute' }),
      `customer:${customerUserId}`,
    ],
  );
  return result.rows[0];
}

async function listDues(client, { customerUserId = null, status = null, limit = 20, offset = 0 } = {}) {
  const result = await client.query(
    `WITH roots AS (
       SELECT due.*,
         EXISTS (
           SELECT 1 FROM app.customer_ledger_entries AS event
           WHERE event.related_entry_id = due.id
             AND event.entry_type = 'due_confirmed'
             AND event.evidence->>'kind' = 'confirmation'
         ) AS is_confirmed,
         EXISTS (
           SELECT 1 FROM app.customer_ledger_entries AS event
           WHERE event.related_entry_id = due.id
             AND event.entry_type = 'waived'
             AND event.evidence->>'kind' = 'waiver'
         ) AS is_waived,
         COALESCE((
           SELECT sum(event.amount_minor)
           FROM app.customer_ledger_entries AS event
           WHERE event.related_entry_id = due.id
             AND event.entry_type = 'payment_received'
         ), 0)::text AS paid_minor,
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object(
             'message', event.note, 'createdAt', event.created_at
           ) ORDER BY event.created_at)
           FROM app.customer_ledger_entries AS event
           WHERE event.related_entry_id = due.id
             AND event.evidence->>'kind' = 'dispute'
         ), '[]'::jsonb) AS disputes
       FROM app.customer_ledger_entries AS due
       WHERE due.entry_type = 'due_pending_review'
         AND due.related_entry_id IS NULL
         AND ($1::uuid IS NULL OR due.customer_user_id = $1)
     ), statuses AS (
       SELECT roots.*,
         CASE
           WHEN is_waived THEN 'waived'
           WHEN is_confirmed AND paid_minor::numeric >= amount_minor THEN 'paid'
           WHEN is_confirmed THEN 'confirmed'
           ELSE 'pending_review'
         END AS due_status
       FROM roots
     )
     SELECT id, customer_user_id, order_id, entry_type,
            amount_minor::text AS amount_minor, currency, reason, note,
            created_at, paid_minor, disputes, due_status AS status
     FROM statuses
     WHERE $2::text IS NULL OR due_status = $2
     ORDER BY created_at DESC, id DESC
     LIMIT $3 OFFSET $4`,
    [customerUserId, status, limit, offset],
  );
  return result.rows;
}

module.exports = {
  LedgerError,
  addDispute,
  confirmDue,
  createPendingDue,
  getOutstandingMinor,
  listDues,
  lockCustomer,
  recordPayment,
  waiveDue,
  withLedgerTransaction,
};
