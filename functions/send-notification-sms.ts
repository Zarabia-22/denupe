import { createAdminClient } from 'npm:@insforge/sdk';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization'
};

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

function secret(key: string): string {
  return (Deno.env.get(key) ?? '').trim();
}

function normalizePhone(rawValue: unknown): string | null {
  const raw = String(rawValue ?? '').trim();
  if (!raw) return null;

  if (raw.startsWith('+')) {
    const digits = raw.slice(1).replace(/\D/g, '');
    return /^[1-9]\d{7,14}$/.test(digits) ? `+${digits}` : null;
  }

  let digits = raw.replace(/\D/g, '');
  if (digits.startsWith('00')) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith('51')) digits = digits.slice(2);
  if (digits.length === 9 && digits.startsWith('9')) return `+51${digits}`;
  return null;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (error && typeof error === 'object') {
    const candidate = error as Record<string, unknown>;
    return String(candidate.message ?? candidate.error ?? JSON.stringify(candidate));
  }
  return String(error);
}

export default async function handler(req: Request): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
  }

  const accountSid = secret('TWILIO_ACCOUNT_SID');
  const authToken = secret('TWILIO_AUTH_TOKEN');
  const fromNumber = secret('TWILIO_FROM_NUMBER');
  const messagingServiceSid = secret('TWILIO_MESSAGING_SERVICE_SID');
  const baseUrl = secret('INSFORGE_BASE_URL');
  const apiKey = secret('API_KEY');

  if (!baseUrl || !apiKey) {
    return json({ error: 'INSFORGE_ADMIN_NOT_CONFIGURED' }, 503);
  }
  const authorized =
    req.headers.get('Authorization') === `Bearer ${apiKey}` ||
    req.headers.get('X-API-Key') === apiKey;
  if (!authorized) {
    return json({ error: 'UNAUTHORIZED' }, 401);
  }
  if (!accountSid || !authToken || (!fromNumber && !messagingServiceSid)) {
    return json({ error: 'SMS_PROVIDER_NOT_CONFIGURED' }, 503);
  }

  const admin = createAdminClient({ baseUrl, apiKey });
  const claimed = await admin.database.rpc('claim_notificaciones_sms', { p_limit: 20 });
  if (claimed.error) {
    return json({ error: 'CLAIM_FAILED', message: errorMessage(claimed.error) }, 500);
  }

  const results: Array<Record<string, unknown>> = [];
  for (const row of claimed.data ?? []) {
    const phone = normalizePhone(row.phone);
    if (!phone) {
      await admin.database.rpc('mark_notificacion_sms_fallido', {
        p_id: row.notification_id,
        p_error: 'TELEFONO_INVALIDO',
        p_retry: false
      });
      results.push({ id: row.notification_id, status: 'skipped', error: 'TELEFONO_INVALIDO' });
      continue;
    }

    const form = new URLSearchParams({
      To: phone,
      Body: `${row.title ?? ''}\n${row.body ?? ''}`.slice(0, 1500)
    });
    if (messagingServiceSid) {
      form.set('MessagingServiceSid', messagingServiceSid);
    } else {
      form.set('From', fromNumber);
    }

    try {
      const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Messages.json`,
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: form.toString()
        }
      );

      if (!response.ok) {
        throw new Error(`TWILIO_${response.status}: ${(await response.text()).slice(0, 300)}`);
      }

      const payload = await response.json();
      await admin.database.rpc('mark_notificacion_sms_enviado', {
        p_id: row.notification_id,
        p_provider_id: String(payload.sid ?? '')
      });
      results.push({ id: row.notification_id, status: 'sent', sid: payload.sid ?? null });
    } catch (error) {
      const message = errorMessage(error);
      await admin.database.rpc('mark_notificacion_sms_fallido', {
        p_id: row.notification_id,
        p_error: message,
        p_retry: true
      });
      results.push({ id: row.notification_id, status: 'failed', error: message });
    }
  }

  return json({ claimed: (claimed.data ?? []).length, results });
}
