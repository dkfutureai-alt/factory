/**
 * PostgREST embeds a many-to-one relationship as an object, while callers may
 * still receive arrays from explicitly spread/multi-row relationship shapes.
 */
export function firstRelatedRow<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null;
  return value ?? null;
}

/**
 * FCM 400/404 alone is not evidence of an invalid token: project configuration
 * or message payload errors can produce the same HTTP statuses. Only a
 * structured FcmError UNREGISTERED response is safe to deactivate.
 */
export function shouldDeactivateFcmDevice(httpStatus: number, rawBody: string): boolean {
  if (httpStatus !== 400 && httpStatus !== 404) return false;
  try {
    const payload = JSON.parse(rawBody) as {
      error?: { details?: Array<{ '@type'?: string; errorCode?: string }> };
    };
    return payload?.error?.details?.some((detail) =>
      detail?.['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError' &&
      detail?.errorCode === 'UNREGISTERED'
    ) ?? false;
  } catch {
    return false;
  }
}

/** Every actionable FCM notification must be bound to its authoritative
 * organization and recipient. A route string alone is never a workspace key.
 * Mobile intentionally refuses to open older unscoped push notifications. */
export function scopedPushRouteData(row: {
  organization_id: string;
  recipient_user_id: string;
  action_route: string | null;
}): Record<string, string> {
  return {
    organization_id: row.organization_id,
    recipient_user_id: row.recipient_user_id,
    action_route: row.action_route ?? '',
  };
}

/**
 * All rows claimed in this batch must still hold exactly those lease tokens.
 * Reject missing, duplicate or superseded claims before a single FCM send.
 * This is a defensive check in addition to the DB's fenced completion update.
 */
export function claimedQueueMatches(
  claimed: Array<{ id: string; claim_token: string }>,
  queue: Array<{ id: string; claim_token: string }>,
): boolean {
  if (claimed.length !== queue.length) return false;
  const byId = new Map<string, string>();
  for (const row of claimed) {
    if (!row || typeof row.id !== 'string' || !row.id ||
        typeof row.claim_token !== 'string' || !row.claim_token ||
        byId.has(row.id)) return false;
    byId.set(row.id, row.claim_token);
  }
  const observed = new Set<string>();
  for (const row of queue) {
    if (!row || typeof row.id !== 'string' ||
        typeof row.claim_token !== 'string' ||
        observed.has(row.id) || byId.get(row.id) !== row.claim_token) {
      return false;
    }
    observed.add(row.id);
  }
  return true;
}
