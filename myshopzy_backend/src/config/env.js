const POSTGRES_ENV_KEYS = [
  'PGHOST',
  'PGPORT',
  'PGDATABASE',
  'PGUSER',
  'PGPASSWORD',
];

const DEFAULT_SUPPORT_PHONE = '+91 88972 67490';
const DEFAULT_SUPPORT_ESCALATION_MINUTES = 10;

function parsePositiveIntegerEnv(env, name, fallback) {
  const raw = env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }
  return value;
}

function loadConfig(env = process.env) {
  const rawPort = env.PORT || '3000';
  const port = Number(rawPort);

  if (!/^\d+$/.test(rawPort) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }

  const configuredPostgresKeys = POSTGRES_ENV_KEYS.filter(
    (key) => env[key] !== undefined && env[key] !== '',
  );

  let database = null;

  if (configuredPostgresKeys.length > 0) {
    const missingKeys = POSTGRES_ENV_KEYS.filter(
      (key) => env[key] === undefined || env[key] === '',
    );
    if (missingKeys.length > 0) {
      throw new Error(
        `PostgreSQL configuration is incomplete. Set: ${missingKeys.join(', ')}.`,
      );
    }

    if (env.PGDATABASE !== 'myshopzy') {
      throw new Error('PGDATABASE must be set to myshopzy.');
    }

    const databasePort = Number(env.PGPORT);
    if (
      !/^\d+$/.test(env.PGPORT) ||
      !Number.isInteger(databasePort) ||
      databasePort < 1 ||
      databasePort > 65535
    ) {
      throw new Error('PGPORT must be an integer between 1 and 65535.');
    }

    database = Object.freeze({
      host: env.PGHOST,
      port: databasePort,
      database: env.PGDATABASE,
      user: env.PGUSER,
      password: env.PGPASSWORD,
    });
  }

  const auth0IssuerUrl = env.AUTH0_ISSUER_URL?.trim() || null;
  const auth0Audience = env.AUTH0_AUDIENCE?.trim() || null;
  const auth0AdminUserIdClaim =
    env.AUTH0_ADMIN_USER_ID_CLAIM?.trim() || null;
  const auth0PartnerEmailClaim =
    env.AUTH0_PARTNER_EMAIL_CLAIM?.trim() || 'email';
  const auth0PartnerEmailVerifiedClaim =
    env.AUTH0_PARTNER_EMAIL_VERIFIED_CLAIM?.trim() || 'email_verified';
  const superAdminOrigin = env.SUPER_ADMIN_ORIGIN?.trim() || null;
  const partnerPortalOrigins = (
    env.PARTNER_PORTAL_ORIGINS?.trim() || 'http://localhost:5173'
  )
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const routingProvider = env.ROUTING_PROVIDER?.trim() || 'google';
  if (!['google', 'fake'].includes(routingProvider)) {
    throw new Error('ROUTING_PROVIDER must be google or fake.');
  }
  const supportPhone = env.SUPPORT_PHONE?.trim() || DEFAULT_SUPPORT_PHONE;
  const supportEscalationMinutes = parsePositiveIntegerEnv(
    env,
    'SUPPORT_ESCALATION_MINUTES',
    DEFAULT_SUPPORT_ESCALATION_MINUTES,
  );

  if (Boolean(auth0IssuerUrl) !== Boolean(auth0Audience)) {
    throw new Error('Set both AUTH0_ISSUER_URL and AUTH0_AUDIENCE.');
  }

  let issuer = null;
  if (auth0IssuerUrl) {
    try {
      issuer = new URL(auth0IssuerUrl);
    } catch {
      throw new Error('AUTH0_ISSUER_URL must be a valid URL.');
    }
    if (
      issuer.protocol !== 'https:' ||
      issuer.username ||
      issuer.password ||
      issuer.search ||
      issuer.hash ||
      issuer.pathname !== '/'
    ) {
      throw new Error('AUTH0_ISSUER_URL must be an HTTPS Auth0 issuer origin.');
    }
  }

  let normalizedSuperAdminOrigin = null;
  if (superAdminOrigin) {
    let origin;
    try {
      origin = new URL(superAdminOrigin);
    } catch {
      throw new Error('SUPER_ADMIN_ORIGIN must be a valid URL.');
    }
    if (
      origin.origin !== superAdminOrigin.replace(/\/+$/, '') ||
      (origin.protocol !== 'https:' &&
        !(origin.protocol === 'http:' &&
          ['localhost', '127.0.0.1'].includes(origin.hostname)))
    ) {
      throw new Error('SUPER_ADMIN_ORIGIN must be a valid HTTPS origin.');
    }
    normalizedSuperAdminOrigin = origin.origin;
  }

  for (const configuredOrigin of partnerPortalOrigins) {
    let origin;
    try {
      origin = new URL(configuredOrigin);
    } catch {
      throw new Error(
        'PARTNER_PORTAL_ORIGINS must contain HTTPS origins or HTTP localhost origins.',
      );
    }
    if (
      configuredOrigin === '*' ||
      origin.origin !== configuredOrigin.replace(/\/+$/, '') ||
      (origin.protocol !== 'https:' &&
        !(origin.protocol === 'http:' &&
          ['localhost', '127.0.0.1'].includes(origin.hostname)))
    ) {
      throw new Error(
        'PARTNER_PORTAL_ORIGINS must contain HTTPS origins or HTTP localhost origins.',
      );
    }
  }
  const normalizedPartnerPortalOrigins = [
    ...new Set(partnerPortalOrigins.map((origin) => new URL(origin).origin)),
  ];

  if (auth0AdminUserIdClaim) {
    if (!auth0IssuerUrl || !auth0Audience || !normalizedSuperAdminOrigin) {
      throw new Error(
        'Super Admin authentication requires AUTH0_ISSUER_URL, AUTH0_AUDIENCE, and SUPER_ADMIN_ORIGIN.',
      );
    }
    let adminUserIdClaim;
    try {
      adminUserIdClaim = new URL(auth0AdminUserIdClaim);
    } catch {
      throw new Error('AUTH0_ADMIN_USER_ID_CLAIM must be an HTTPS claim namespace URI.');
    }
    if (adminUserIdClaim.protocol !== 'https:') {
      throw new Error('AUTH0_ADMIN_USER_ID_CLAIM must be an HTTPS claim namespace URI.');
    }
  }

  const auth0Partner = issuer
    ? Object.freeze({
        issuerUrl: issuer.href,
        audience: auth0Audience,
        emailClaim: auth0PartnerEmailClaim,
        emailVerifiedClaim: auth0PartnerEmailVerifiedClaim,
      })
    : null;
  const auth0Admin = auth0AdminUserIdClaim
    ? Object.freeze({
        issuerUrl: issuer.href,
        audience: auth0Audience,
        adminUserIdClaim: auth0AdminUserIdClaim,
      })
    : null;

  const otpConfigKeys = [
    'CUSTOMER_OTP_PEPPER',
    'CUSTOMER_SESSION_SECRET',
    'WHATSAPP_ACCESS_TOKEN',
    'WHATSAPP_PHONE_NUMBER_ID',
    'WHATSAPP_OTP_TEMPLATE_NAME',
    'WHATSAPP_OTP_TEMPLATE_LANGUAGE',
  ];
  const otpConfigProvided = otpConfigKeys.some(
    (key) => env[key] !== undefined && env[key] !== '',
  );
  let customerOtpPepper = null;
  let customerSessionSecret = null;
  let whatsapp = null;

  if (otpConfigProvided) {
    const requiredValues = {
      CUSTOMER_OTP_PEPPER: env.CUSTOMER_OTP_PEPPER,
      CUSTOMER_SESSION_SECRET: env.CUSTOMER_SESSION_SECRET,
      WHATSAPP_ACCESS_TOKEN: env.WHATSAPP_ACCESS_TOKEN,
      WHATSAPP_PHONE_NUMBER_ID: env.WHATSAPP_PHONE_NUMBER_ID,
      WHATSAPP_OTP_TEMPLATE_NAME: env.WHATSAPP_OTP_TEMPLATE_NAME,
      WHATSAPP_OTP_TEMPLATE_LANGUAGE: env.WHATSAPP_OTP_TEMPLATE_LANGUAGE,
    };
    const missingKeys = Object.entries(requiredValues)
      .filter(([, value]) => !value)
      .map(([key]) => key);
    if (missingKeys.length > 0) {
      throw new Error(
        `Customer OTP authentication configuration is incomplete. Set: ${missingKeys.join(', ')}.`,
      );
    }
    if (
      Buffer.byteLength(env.CUSTOMER_OTP_PEPPER, 'utf8') < 32 ||
      Buffer.byteLength(env.CUSTOMER_SESSION_SECRET, 'utf8') < 32
    ) {
      throw new Error(
        'CUSTOMER_OTP_PEPPER and CUSTOMER_SESSION_SECRET must be at least 32 bytes.',
      );
    }
    const graphApiVersion = env.WHATSAPP_GRAPH_API_VERSION || 'v25.0';
    if (!/^v\d+\.\d+$/.test(graphApiVersion)) {
      throw new Error('WHATSAPP_GRAPH_API_VERSION must look like v25.0.');
    }
    customerOtpPepper = env.CUSTOMER_OTP_PEPPER;
    customerSessionSecret = env.CUSTOMER_SESSION_SECRET;
    whatsapp = Object.freeze({
      accessToken: env.WHATSAPP_ACCESS_TOKEN,
      phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID,
      templateName: env.WHATSAPP_OTP_TEMPLATE_NAME,
      templateLanguage: env.WHATSAPP_OTP_TEMPLATE_LANGUAGE,
      graphApiVersion,
    });
  }

  return Object.freeze({
    port,
    nodeEnv: env.NODE_ENV || 'development',
    database,
    googleMapsApiKey: env.GOOGLE_MAPS_API_KEY?.trim() || null,
    routingProvider,
    routingApiKey: env.ROUTING_API_KEY?.trim() || null,
    supportPhone,
    supportEscalationMinutes,
    developmentCustomerOtp: env.DEVELOPMENT_CUSTOMER_OTP || null,
    developmentCustomerSessionSecret:
      env.DEVELOPMENT_CUSTOMER_SESSION_SECRET || null,
    customerOtpPepper,
    customerSessionSecret,
    whatsapp,
    auth0Admin,
    auth0Partner,
    superAdminOrigin: normalizedSuperAdminOrigin,
    partnerPortalOrigins: Object.freeze(normalizedPartnerPortalOrigins),
  });
}

module.exports = { loadConfig };
