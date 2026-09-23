/**
 * Date range helpers for platform and restaurant analytics.
 * Computes deterministic Date objects for query filtering.
 */

function getStartOfDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function getEndOfDay(date = new Date()) {
  const d = new Date(date);
  d.setHours(23, 59, 59, 999);
  return d;
}

function getTodayRange() {
  const now = new Date();
  return { start: getStartOfDay(now), end: getEndOfDay(now) };
}

function getYesterdayRange() {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return { start: getStartOfDay(d), end: getEndOfDay(d) };
}

function getLast7DaysRange() {
  const now = new Date();
  const start = new Date(now);
  start.setDate(start.getDate() - 6);
  return { start: getStartOfDay(start), end: getEndOfDay(now) };
}

function getLast30DaysRange() {
  const now = new Date();
  const start = new Date(now);
  start.setDate(start.getDate() - 29);
  return { start: getStartOfDay(start), end: getEndOfDay(now) };
}

function getThisWeekRange() {
  const now = new Date();
  const day = now.getDay();
  // Sunday = 0, Monday = 1 ... shift so Monday is start of week
  const diffToMonday = day === 0 ? 6 : day - 1;
  const start = new Date(now);
  start.setDate(start.getDate() - diffToMonday);
  return { start: getStartOfDay(start), end: getEndOfDay(now) };
}

function getThisMonthRange() {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
  return { start, end: getEndOfDay(now) };
}

function getDateRangeForPeriod(period, startDateRaw, endDateRaw) {
  if (startDateRaw || endDateRaw) {
    const start = startDateRaw ? getStartOfDay(new Date(startDateRaw)) : new Date(0);
    const end = endDateRaw ? getEndOfDay(new Date(endDateRaw)) : new Date();
    return { start, end, label: 'custom' };
  }

  const p = (period || 'all').toLowerCase();
  switch (p) {
    case 'today':
      return { ...getTodayRange(), label: 'today' };
    case 'yesterday':
      return { ...getYesterdayRange(), label: 'yesterday' };
    case '7days':
    case 'last7days':
      return { ...getLast7DaysRange(), label: '7days' };
    case '30days':
    case 'last30days':
      return { ...getLast30DaysRange(), label: '30days' };
    case 'thisweek':
    case 'week':
      return { ...getThisWeekRange(), label: 'thisWeek' };
    case 'thismonth':
    case 'month':
      return { ...getThisMonthRange(), label: 'thisMonth' };
    case 'all':
    default:
      return null;
  }
}

module.exports = {
  getStartOfDay,
  getEndOfDay,
  getTodayRange,
  getYesterdayRange,
  getLast7DaysRange,
  getLast30DaysRange,
  getThisWeekRange,
  getThisMonthRange,
  getDateRangeForPeriod,
};

