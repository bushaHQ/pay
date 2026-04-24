// Minimal URL helpers. RN's URL polyfill is patchy across platforms, so we
// parse by hand to avoid drift.

export const encodeQuery = (params: Record<string, string>): string =>
  Object.entries(params)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');

export const getOrigin = (absoluteUrl: string): string => {
  const m = absoluteUrl.match(/^([a-z][a-z0-9+.-]*:\/\/[^/]+)/i);
  return m ? (m[1] as string) : absoluteUrl;
};

export type ParsedUrl = {
  scheme: string;
  host: string;
  path: string;
  query: Record<string, string>;
};

export const parseUrl = (url: string): ParsedUrl | null => {
  const m = url.match(/^([a-z][a-z0-9+.-]*):\/\/([^/?#]*)([^?#]*)(\?[^#]*)?/i);
  if (!m) return null;
  const scheme = (m[1] as string).toLowerCase();
  const host = (m[2] ?? '') as string;
  const path = (m[3] ?? '') as string;
  const rawQuery = (m[4] ?? '').replace(/^\?/, '');
  const query: Record<string, string> = {};
  if (rawQuery) {
    for (const pair of rawQuery.split('&')) {
      if (!pair) continue;
      const eq = pair.indexOf('=');
      const k = eq === -1 ? pair : pair.substring(0, eq);
      const v = eq === -1 ? '' : pair.substring(eq + 1);
      try {
        query[decodeURIComponent(k)] = decodeURIComponent(v);
      } catch {
        query[k] = v;
      }
    }
  }
  return { scheme, host, path, query };
};
