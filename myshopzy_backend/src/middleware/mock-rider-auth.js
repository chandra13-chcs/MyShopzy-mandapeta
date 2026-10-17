const DEMO_RIDER_ID = '00000000-0000-4000-8000-000000000001';
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function mockRiderAuth(req, res, next) {
  const riderUserId = req.get('X-Rider-Id') || DEMO_RIDER_ID;
  if (!UUID_PATTERN.test(riderUserId)) {
    return res.status(400).json({
      error: {
        code: 'INVALID_RIDER_ID',
        message: 'X-Rider-Id must be a valid UUID.',
      },
    });
  }

  req.auth = { ...req.auth, riderUserId };
  return next();
}

module.exports = { DEMO_RIDER_ID, mockRiderAuth };
