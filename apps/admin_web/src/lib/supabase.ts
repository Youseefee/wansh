import { createClient } from '@supabase/supabase-js';

const FALLBACK_SUPABASE_URL = 'https://ytwpenavwybfmxawiadj.supabase.co';
const FALLBACK_SUPABASE_ANON_KEY = 'sb_publishable_WC2QHX2G2TdN0jvUAkrM_Q_QT7kYxL5';

export const SUPABASE_URL =
  (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.trim() || FALLBACK_SUPABASE_URL;

export const SUPABASE_ANON_KEY =
  (import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined)?.trim() ||
  FALLBACK_SUPABASE_ANON_KEY;

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
  realtime: {
    params: {
      eventsPerSecond: 5,
    },
  },
});

export function getPublicWinchPhotoUrl(path: string): string {
  if (!path) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  const { data } = supabase.storage.from('winch-photos').getPublicUrl(path);
  return data.publicUrl;
}

export async function getSignedPrivateUrl(
  bucket: 'driver-documents' | 'complaint-evidence' | 'breakdown-photos',
  path: string,
  expiresInSeconds = 3600
): Promise<string | null> {
  if (!path) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrl(path, expiresInSeconds);
  if (error || !data?.signedUrl) {
    return null;
  }
  return data.signedUrl;
}

export function isPdfPath(path: string): boolean {
  return path.toLowerCase().split('?')[0].endsWith('.pdf');
}
