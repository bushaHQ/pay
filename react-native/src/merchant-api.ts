const TIMEOUT_MS = 5000;

export const fetchMerchantName = async (
  publicKey: string,
  platformUrl: string,
  fetchImpl: typeof fetch = fetch
): Promise<string | null> => {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const response = await fetchImpl(`${platformUrl}/v1/merchants`, {
      method: 'GET',
      headers: { 'X-BU-PUBLIC-KEY': publicKey },
      signal: controller.signal,
    });
    if (response.status < 200 || response.status >= 300) return null;
    const body = await response.json();
    const username = (body as { data?: { username?: unknown } })?.data
      ?.username;
    return typeof username === 'string' && username.length > 0
      ? username
      : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
};
