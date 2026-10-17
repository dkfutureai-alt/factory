import { createClient } from 'npm:@supabase/supabase-js@2';

const jsonHeaders = { 'Content-Type': 'application/json' };

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function base64Url(input: Uint8Array | string) {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function pemToBytes(pem: string) {
  const clean = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const binary = atob(clean);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function googleAccessToken(clientEmail: string, privateKeyPem: string) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64Url(JSON.stringify({
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)));
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!response.ok) throw new Error(`Google OAuth failed: ${response.status} ${await response.text()}`);
  const data = await response.json() as { access_token?: string };
  if (!data.access_token) throw new Error('Google OAuth returned no access token');
  return data.access_token;
}

type NotificationRow = {
  organization_id: string;
  recipient_user_id: string;
  title: string;
  body: string;
  action_route: string | null;
  action_entity_id: string | null;
  priority: string;
  category: string;
  metadata: Record<string, unknown>;
};

type QueueRow = {
  id: string;
  notification_id: string;
  attempts: number;
  notifications: NotificationRow[];
};

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' });
  const dispatchSecret = Deno.env.get('NOTIFICATION_DISPATCH_SECRET') ?? '';
  if (!dispatchSecret || req.headers.get('x-notification-secret') !== dispatchSecret) {
    return json(401, { error: 'Invalid dispatch secret' });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const projectId = Deno.env.get('FCM_PROJECT_ID') ?? '';
    const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL') ?? '';
    const privateKey = (Deno.env.get('FCM_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n');
    if (!supabaseUrl || !serviceRoleKey || !projectId || !clientEmail || !privateKey) {
      return json(503, { error: 'Push delivery environment is not configured' });
    }

    const service = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: queue, error: queueError } = await service
      .from('notification_deliveries')
      .select('id,notification_id,attempts,notifications(organization_id,recipient_user_id,title,body,action_route,action_entity_id,priority,category,metadata)')
      .eq('channel', 'push')
      .eq('status', 'queued')
      .order('created_at')
      .limit(50);
    if (queueError) throw queueError;
    if (!queue?.length) return json(200, { processed: 0, sent: 0, failed: 0, skipped: 0 });

    const accessToken = await googleAccessToken(clientEmail, privateKey);
    let sent = 0;
    let failed = 0;
    let skipped = 0;

    for (const raw of queue as QueueRow[]) {
      const notification = raw.notifications?.[0];
      if (!notification) {
        await service.from('notification_deliveries').update({ status: 'failed', attempts: raw.attempts + 1, last_attempt_at: new Date().toISOString(), error_message: 'Notification row missing' }).eq('id', raw.id);
        failed++;
        continue;
      }
      const { data: devices, error: deviceError } = await service
        .from('notification_devices')
        .select('id,device_token')
        .eq('organization_id', notification.organization_id)
        .eq('user_id', notification.recipient_user_id)
        .eq('is_active', true);
      if (deviceError) throw deviceError;
      if (!devices?.length) {
        await service.from('notification_deliveries').update({ status: 'skipped', attempts: raw.attempts + 1, last_attempt_at: new Date().toISOString(), error_message: 'No active device' }).eq('id', raw.id);
        skipped++;
        continue;
      }

      let deliverySent = false;
      let lastError = '';
      let providerMessageId: string | null = null;
      for (const device of devices) {
        const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: {
              token: device.device_token,
              notification: { title: notification.title, body: notification.body },
              data: {
                notification_id: raw.notification_id,
                action_route: notification.action_route ?? '',
                action_entity_id: notification.action_entity_id ?? '',
                priority: notification.priority,
                category: notification.category,
                metadata: JSON.stringify(notification.metadata ?? {}),
              },
              android: { priority: notification.priority === 'critical' || notification.priority === 'high' ? 'HIGH' : 'NORMAL' },
            },
          }),
        });
        if (response.ok) {
          const data = await response.json() as { name?: string };
          providerMessageId = data.name ?? providerMessageId;
          deliverySent = true;
        } else {
          lastError = `${response.status} ${await response.text()}`.slice(0, 1000);
          if (response.status === 404 || response.status === 400) {
            await service.from('notification_devices').update({ is_active: false }).eq('id', device.id);
          }
        }
      }

      await service.from('notification_deliveries').update({
        status: deliverySent ? 'sent' : 'failed',
        attempts: raw.attempts + 1,
        last_attempt_at: new Date().toISOString(),
        provider_message_id: providerMessageId,
        error_message: deliverySent ? null : (lastError || 'FCM delivery failed'),
      }).eq('id', raw.id);
      if (deliverySent) sent++; else failed++;
    }

    return json(200, { processed: queue.length, sent, failed, skipped });
  } catch (error) {
    return json(500, { error: error instanceof Error ? error.message : String(error) });
  }
});