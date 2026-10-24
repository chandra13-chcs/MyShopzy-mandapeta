const assert = require('node:assert/strict');
const { readFile } = require('node:fs/promises');
const path = require('node:path');
const test = require('node:test');

const {
  LedgerError,
  confirmDue,
  getOutstandingMinor,
  recordPayment,
} = require('../../src/modules/dues/ledger');

const customerId = '27dcad4a-f166-4fc8-a224-3d1c099dd459';
const dueId = 'f3caf63d-228d-47b7-9dfd-ecc178c595f2';

function createLedgerClient(initialEntries) {
  const entries = initialEntries.map((entry) => ({ ...entry }));
  return {
    entries,
    async query(sql, params = []) {
      const normalized = sql.replace(/\s+/g, ' ').trim();
      if (normalized.startsWith('SELECT user_id FROM app.customers')) {
        return { rows: [{ user_id: params[0] }] };
      }
      if (normalized.startsWith('SELECT COALESCE(sum(')) {
        const outstanding = entries.reduce((total, entry) => {
          if (entry.customer_user_id !== params[0]) return total;
          if (
            entry.entry_type === 'due_confirmed' &&
            entry.kind === 'confirmation'
          ) {
            return total + BigInt(entry.amount_minor);
          }
          if (entry.entry_type === 'payment_received') {
            return total - BigInt(entry.amount_minor);
          }
          if (entry.entry_type === 'waived') {
            const confirmed = entries.some(
              (candidate) =>
                candidate.related_entry_id === entry.related_entry_id &&
                candidate.entry_type === 'due_confirmed' &&
                candidate.kind === 'confirmation',
            );
            if (confirmed) return total - BigInt(entry.amount_minor);
          }
          return total;
        }, 0n);
        return { rows: [{ outstanding_minor: outstanding.toString() }] };
      }
      if (normalized.startsWith('SELECT confirmation.related_entry_id')) {
        const confirmations = entries.filter(
          (entry) =>
            entry.customer_user_id === params[0] &&
            entry.entry_type === 'due_confirmed' &&
            entry.kind === 'confirmation',
        );
        return {
          rows: confirmations.map((confirmation) => ({
            due_entry_id: confirmation.related_entry_id,
            amount_minor: confirmation.amount_minor,
            currency: confirmation.currency,
            settled_minor: entries
              .filter(
                (entry) =>
                  entry.related_entry_id === confirmation.related_entry_id &&
                  ['payment_received', 'waived'].includes(entry.entry_type),
              )
              .reduce((sum, entry) => sum + BigInt(entry.amount_minor), 0n)
              .toString(),
          })),
        };
      }
      if (normalized.startsWith('INSERT INTO app.customer_ledger_entries')) {
        const row = {
          id: params[0],
          customer_user_id: params[1],
          related_entry_id: params[2],
          entry_type: 'payment_received',
          amount_minor: params[3],
          currency: params[4],
          note: params[5],
          kind: 'payment',
        };
        entries.push(row);
        return { rows: [row] };
      }
      assert.fail(`Unexpected ledger query: ${normalized}`);
    },
  };
}

test('balance counts confirmed dues, payments, and waivers but ignores pending dues and disputes', async () => {
  const client = createLedgerClient([
    {
      id: 'pending',
      customer_user_id: customerId,
      entry_type: 'due_pending_review',
      amount_minor: '900',
    },
    {
      id: dueId,
      customer_user_id: customerId,
      related_entry_id: 'pending',
      entry_type: 'due_confirmed',
      amount_minor: '1000',
      currency: 'INR',
      kind: 'confirmation',
    },
    {
      id: 'dispute',
      customer_user_id: customerId,
      related_entry_id: dueId,
      entry_type: 'due_confirmed',
      amount_minor: '1000',
      kind: 'dispute',
    },
    {
      id: 'payment',
      customer_user_id: customerId,
      related_entry_id: 'pending',
      entry_type: 'payment_received',
      amount_minor: '200',
    },
    {
      id: 'waiver',
      customer_user_id: customerId,
      related_entry_id: 'pending',
      entry_type: 'waived',
      amount_minor: '100',
    },
  ]);
  assert.equal(await getOutstandingMinor(client, customerId), 700n);
});

test('pending-review dues alone never block checkout', async () => {
  const client = createLedgerClient([
    {
      id: dueId,
      customer_user_id: customerId,
      entry_type: 'due_pending_review',
      amount_minor: '1000',
    },
  ]);
  assert.equal(await getOutstandingMinor(client, customerId), 0n);
});

test('recording a payment clears the confirmed balance and rejects overpayment', async () => {
  const client = createLedgerClient([
    {
      id: 'pending',
      customer_user_id: customerId,
      entry_type: 'due_pending_review',
      amount_minor: '500',
    },
    {
      id: 'confirmation',
      customer_user_id: customerId,
      related_entry_id: 'pending',
      entry_type: 'due_confirmed',
      amount_minor: '500',
      currency: 'INR',
      kind: 'confirmation',
    },
  ]);
  await assert.rejects(
    recordPayment(client, {
      customerUserId: customerId,
      amountMinor: 501,
      reference: 'receipt-1',
      adminUserId: 'a8c2ee15-7b78-4e88-a473-35b95647f419',
    }),
    (error) => error instanceof LedgerError && error.code === 'OVERPAYMENT',
  );
  assert.equal(client.entries.filter((entry) => entry.entry_type === 'payment_received').length, 0);
  await recordPayment(client, {
    customerUserId: customerId,
    amountMinor: 500,
    reference: 'receipt-2',
    adminUserId: 'a8c2ee15-7b78-4e88-a473-35b95647f419',
  });
  assert.equal(await getOutstandingMinor(client, customerId), 0n);
  assert.equal(
    client.entries.at(-1).related_entry_id,
    'pending',
  );
});

test('confirming a pending due creates one confirmation event and rejects a second', async () => {
  const events = [];
  const rootDue = {
    id: dueId,
    customer_user_id: customerId,
    order_id: 'd1ca6b39-b9d9-423b-b93b-3e513f232d9a',
    entry_type: 'due_pending_review',
    amount_minor: '900',
    currency: 'INR',
    reason: 'customer_refused',
  };
  const client = {
    async query(sql, params = []) {
      const normalized = sql.replace(/\s+/g, ' ').trim();
      if (normalized.startsWith('SELECT id, customer_user_id, order_id')) {
        return { rows: [rootDue] };
      }
      if (normalized.startsWith('SELECT user_id FROM app.customers')) {
        return { rows: [{ user_id: params[0] }] };
      }
      if (normalized.includes("evidence->>'kind' IN ('confirmation', 'waiver')")) {
        return { rows: events };
      }
      if (normalized.startsWith('INSERT INTO app.customer_ledger_entries')) {
        const event = {
          id: params[0],
          related_entry_id: params[3],
          entry_type: 'due_confirmed',
          amount_minor: params[4],
          currency: params[5],
          evidence: JSON.parse(params[8]),
        };
        events.push(event);
        return { rows: [event] };
      }
      assert.fail(`Unexpected ledger query: ${normalized}`);
    },
  };
  const input = {
    dueEntryId: dueId,
    adminUserId: 'a8c2ee15-7b78-4e88-a473-35b95647f419',
    supportReference: 'SUP-123',
    note: 'Reviewed delivery evidence',
  };
  const confirmation = await confirmDue(client, input);
  assert.equal(confirmation.amount_minor, '900');
  assert.equal(confirmation.evidence.supportReference, 'SUP-123');
  await assert.rejects(
    confirmDue(client, input),
    (error) => error instanceof LedgerError && error.code === 'DUE_ALREADY_RESOLVED',
  );
  assert.equal(events.length, 1);
});

test('ledger service contains no update or delete path', async () => {
  const service = await readFile(
    path.resolve(__dirname, '../../src/modules/dues/ledger.js'),
    'utf8',
  );
  assert.doesNotMatch(service, /\bUPDATE\s+app\.customer_ledger_entries\b/i);
  assert.doesNotMatch(service, /\bDELETE\s+FROM\s+app\.customer_ledger_entries\b/i);
});
