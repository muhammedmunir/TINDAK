// TINDAK — url-check (M8b)
//
// The only place a user's chosen URL leaves TINDAK's control, and the only
// place the Web Risk key exists. The app never calls Google directly: a key in
// the APK is a key anyone can read (docs/12_SECURITY.md section 6, AI Rule 9).
//
// Contract: docs/13_API.md section 3.2. The response carries stable codes, not
// prose — the app owns every word the user reads — and there is no score field
// anywhere, because ADR-009 is enforced by the shape of the API.
//
// What this function accepts: { "url": "<http(s) url>" } and nothing else.
// What it sends onward: that URL. Never the message it came from, the memory,
// other entities, the email, or the user id.
//
// The URL is never written to a log here. A log line is a copy of somebody's
// private link that outlives the request.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const WEB_RISK_ENDPOINT = 'https://webrisk.googleapis.com/v1/uris:search';

/** PD-028. Counted in Postgres against the token's user, not in the app. */
const DAILY_LIMIT = 60;

/** docs/13_API.md section 4: upstream 8s, so the client's 12s can still win. */
const PROVIDER_TIMEOUT_MS = 8000;

/** A URL longer than this is not a link someone shared; it is a payload. */
const MAX_URL_LENGTH = 2000;

/** Threat types TINDAK has copy for. Anything else is still a threat. */
const THREAT_KINDS: Record<string, string> = {
  MALWARE: 'malware',
  SOCIAL_ENGINEERING: 'social_engineering',
  UNWANTED_SOFTWARE: 'unwanted_software',
};

type Outcome =
  | 'no_known_threat'
  | 'threat'
  | 'unavailable'
  | 'quota_reached'
  | 'unauthenticated'
  | 'invalid_request';

function reply(outcome: Outcome, extra: Record<string, unknown> = {}) {
  const status = outcome === 'unauthenticated'
    ? 401
    : outcome === 'invalid_request'
    ? 400
    : outcome === 'quota_reached'
    ? 429
    : 200;

  return new Response(JSON.stringify({ outcome, ...extra }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** http or https, with a real host, and nothing else. */
function acceptableUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  if (value.length === 0 || value.length > MAX_URL_LENGTH) return null;

  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return null;
  if (parsed.hostname.length === 0) return null;
  return value;
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return reply('invalid_request');

  // --- the caller must be a real, signed-in TINDAK user -------------------
  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return reply('unauthenticated');

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  // Supabase injects one of these into every function; which one depends on
  // the project's age.
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const webRiskKey = Deno.env.get('WEB_RISK_API_KEY');

  const asCaller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await asCaller.auth.getUser();
  const userId = userData?.user?.id;
  // The user id comes from the verified token, never from the body.
  if (userError || !userId) return reply('unauthenticated');

  // --- exactly one field, and it must be a web link -----------------------
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return reply('invalid_request');
  }
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return reply('invalid_request');
  }
  const keys = Object.keys(body as Record<string, unknown>);
  if (keys.length !== 1 || keys[0] !== 'url') return reply('invalid_request');

  const url = acceptableUrl((body as Record<string, unknown>).url);
  if (url === null) return reply('invalid_request');

  if (!webRiskKey) {
    // Misconfiguration must read as "could not check", never as "nothing
    // found".
    console.error('web_risk_key_missing');
    return reply('unavailable');
  }

  // --- quota, counted atomically before anything is sent ------------------
  const asService = createClient(supabaseUrl, serviceKey);
  const { data: allowed, error: quotaError } = await asService.rpc(
    'consume_reputation_check',
    { p_user: userId, p_limit: DAILY_LIMIT },
  );
  if (quotaError) {
    console.error('quota_check_failed', quotaError.code ?? 'unknown');
    return reply('unavailable');
  }
  if (allowed !== true) return reply('quota_reached');

  // --- the provider -------------------------------------------------------
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

  try {
    const query = new URLSearchParams({
      key: webRiskKey,
      uri: url,
    });
    for (const kind of Object.keys(THREAT_KINDS)) {
      query.append('threatTypes', kind);
    }

    const response = await fetch(`${WEB_RISK_ENDPOINT}?${query}`, {
      signal: controller.signal,
    });

    if (!response.ok) {
      // Status only: a provider error body can echo the URL back.
      console.error('provider_http_error', response.status);
      return reply('unavailable');
    }

    const payload = await response.json();
    const threatTypes: string[] = payload?.threat?.threatTypes ?? [];

    if (threatTypes.length === 0) {
      // "No match on the lists we cover" — not "this link is safe".
      return reply('no_known_threat');
    }

    const known = threatTypes.find((t) => t in THREAT_KINDS);
    return reply('threat', {
      threat_kind: known ? THREAT_KINDS[known] : null,
    });
  } catch (error) {
    const aborted = error instanceof DOMException && error.name === 'AbortError';
    console.error(aborted ? 'provider_timeout' : 'provider_failed');
    return reply('unavailable');
  } finally {
    clearTimeout(timer);
  }
});
