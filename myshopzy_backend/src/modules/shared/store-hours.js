const DEFAULT_TIMEZONE = 'Asia/Kolkata';
const DEFAULT_OPEN = '07:00';
const DEFAULT_CLOSE = '22:00';

function normalizeTime(value, fallback) {
  if (typeof value !== 'string' || !/^\d{2}:\d{2}$/.test(value)) {
    return fallback;
  }

  const [hours, minutes] = value.split(':').map(Number);
  if (hours > 23 || minutes > 59) return fallback;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function isOpenNow(shop, now = new Date()) {
  const operatingDetails =
    shop.operating_details && typeof shop.operating_details === 'object'
      ? shop.operating_details
      : {};
  const opensAt = normalizeTime(operatingDetails.open, DEFAULT_OPEN);
  const closesAt = normalizeTime(operatingDetails.close, DEFAULT_CLOSE);
  const timezone = shop.timezone || DEFAULT_TIMEZONE;
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: timezone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const localTime = parts
    .filter((part) => part.type === 'hour' || part.type === 'minute')
    .map((part) => part.value)
    .join(':');
  const [localHours, localMinutes] = localTime.split(':').map(Number);
  const currentMinutes = localHours * 60 + localMinutes;
  const openingMinutes = Number(opensAt.slice(0, 2)) * 60 + Number(opensAt.slice(3));
  const closingMinutes =
    Number(closesAt.slice(0, 2)) * 60 + Number(closesAt.slice(3));
  const open =
    openingMinutes < closingMinutes
      ? currentMinutes >= openingMinutes && currentMinutes < closingMinutes
      : openingMinutes > closingMinutes
      ? currentMinutes >= openingMinutes || currentMinutes < closingMinutes
      : false;

  return { open, opensAt, closesAt };
}

function formatTimeLabel(time) {
  const [hours, minutes] = time.split(':').map(Number);
  const period = hours < 12 ? 'AM' : 'PM';
  const displayHour = hours % 12 || 12;
  return `${displayHour}:${String(minutes).padStart(2, '0')} ${period}`;
}

function formatHoursMessage({ opensAt, closesAt }) {
  const open = opensAt === closesAt ? DEFAULT_OPEN : opensAt;
  const close = opensAt === closesAt ? DEFAULT_CLOSE : closesAt;
  return `Orders are accepted between ${formatTimeLabel(open)} and ${formatTimeLabel(close)}`;
}

module.exports = { formatHoursMessage, isOpenNow };
