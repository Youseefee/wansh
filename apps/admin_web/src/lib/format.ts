export type Locale = 'ar' | 'en';

export function formatCurrency(amount: number | null | undefined, locale: Locale): string {
  const value = Number(amount ?? 0);
  const formatted = new Intl.NumberFormat(locale === 'ar' ? 'ar-EG' : 'en-EG', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(Number.isFinite(value) ? value : 0);

  return locale === 'ar' ? `${formatted} ج.م` : `${formatted} EGP`;
}

export function formatNumber(value: number | null | undefined, locale: Locale): string {
  const num = Number(value ?? 0);
  return new Intl.NumberFormat(locale === 'ar' ? 'ar-EG' : 'en-US').format(
    Number.isFinite(num) ? num : 0
  );
}

export function formatDateTime(iso: string | null | undefined, locale: Locale): string {
  if (!iso) return '—';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat(locale === 'ar' ? 'ar-EG' : 'en-GB', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}

export function formatDate(iso: string | null | undefined, locale: Locale): string {
  if (!iso) return '—';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat(locale === 'ar' ? 'ar-EG' : 'en-GB', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(date);
}

export function formatRelativeTime(iso: string | null | undefined, locale: Locale): string {
  if (!iso) return '—';
  const date = new Date(iso);
  const diffMs = date.getTime() - Date.now();
  if (Number.isNaN(diffMs)) return '—';

  const absSec = Math.abs(Math.round(diffMs / 1000));
  const rtf = new Intl.RelativeTimeFormat(locale === 'ar' ? 'ar' : 'en', { numeric: 'auto' });

  if (absSec < 60) return rtf.format(Math.round(diffMs / 1000), 'second');
  const diffMin = Math.round(diffMs / 60000);
  if (Math.abs(diffMin) < 60) return rtf.format(diffMin, 'minute');
  const diffHour = Math.round(diffMs / 3600000);
  if (Math.abs(diffHour) < 24) return rtf.format(diffHour, 'hour');
  const diffDay = Math.round(diffMs / 86400000);
  return rtf.format(diffDay, 'day');
}

export function formatDistance(km: number | null | undefined, locale: Locale): string {
  const num = Number(km ?? 0);
  const formatted = new Intl.NumberFormat(locale === 'ar' ? 'ar-EG' : 'en-US', {
    maximumFractionDigits: 1,
  }).format(Number.isFinite(num) ? num : 0);
  return locale === 'ar' ? `${formatted} كم` : `${formatted} km`;
}
