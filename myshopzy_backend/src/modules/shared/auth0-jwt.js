let joseModule;

function loadJose() {
  joseModule ??= import('jose');
  return joseModule;
}

function createAuth0JwtVerifier({ issuerUrl, audience }) {
  if (!issuerUrl || !audience) {
    throw new TypeError('Auth0 issuer and audience are required.');
  }

  let verificationKeySet;
  return async function verifyAuth0Jwt(token) {
    const { createRemoteJWKSet, jwtVerify } = await loadJose();
    verificationKeySet ??= createRemoteJWKSet(
      new URL('.well-known/jwks.json', issuerUrl),
    );
    const { payload } = await jwtVerify(token, verificationKeySet, {
      issuer: issuerUrl,
      audience,
      algorithms: ['RS256'],
      requiredClaims: ['exp', 'sub'],
    });
    return payload;
  };
}

module.exports = { createAuth0JwtVerifier };
