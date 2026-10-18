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
