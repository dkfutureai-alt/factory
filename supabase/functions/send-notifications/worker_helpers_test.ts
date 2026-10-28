import { claimedQueueMatches, firstRelatedRow, scopedPushRouteData, shouldDeactivateFcmDevice } from './worker_helpers.ts';

function expectTrue(condition: boolean, explanation: string) {
  if (!condition) throw new Error(explanation);
}

Deno.test('PostgREST many-to-one embedded object resolves correctly', () => {
  const row = { id: 'notification-1' };
  expectTrue(firstRelatedRow(row) === row, 'object relation was discarded');
  expectTrue(firstRelatedRow([row]) === row, 'array relation was discarded');
  expectTrue(firstRelatedRow([]) === null, 'empty array must be absent');
  expectTrue(firstRelatedRow(null) === null, 'null relation must be absent');
});

Deno.test('FCM UNREGISTERED token is safe to deactivate', () => {
  const body = JSON.stringify({
    error: {
      code: 404,
      status: 'NOT_FOUND',
      details: [{
        '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
        errorCode: 'UNREGISTERED',
      }],
    },
  });
  expectTrue(shouldDeactivateFcmDevice(404, body), 'unregistered device must be detected');
});

Deno.test('generic FCM 400/404 and payload errors never deactivate devices', () => {
  const badRequest = JSON.stringify({
    error: { status: 'INVALID_ARGUMENT', details: [{
      '@type': 'type.googleapis.com/google.rpc.BadRequest',
      fieldViolations: [{ field: 'message.data', description: 'Invalid payload' }],
    }] },
  });
  const invalidArgument = JSON.stringify({
    error: { status: 'INVALID_ARGUMENT', details: [{
      '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
      errorCode: 'INVALID_ARGUMENT',
    }] },
  });
  expectTrue(!shouldDeactivateFcmDevice(400, badRequest), 'payload failures must preserve device');
  expectTrue(!shouldDeactivateFcmDevice(400, invalidArgument), 'ambiguous invalid argument must preserve device');
  expectTrue(!shouldDeactivateFcmDevice(404, '{"error":{"status":"NOT_FOUND"}}'), 'generic 404 must preserve device');
  expectTrue(!shouldDeactivateFcmDevice(404, 'not-json'), 'malformed error must preserve device');
  expectTrue(!shouldDeactivateFcmDevice(500, '{}'), 'server error must preserve device');
});

Deno.test('push navigation carries authoritative organization and recipient identifiers', () => {
  const data = scopedPushRouteData({
    organization_id: 'org-a',
    recipient_user_id: 'user-a',
    action_route: 'inventory',
  });
  expectTrue(data.organization_id === 'org-a', 'tenant scope was lost');
  expectTrue(data.recipient_user_id === 'user-a', 'recipient scope was lost');
  expectTrue(data.action_route === 'inventory', 'route was lost');
  const withoutRoute = scopedPushRouteData({
    organization_id: 'org-b',
    recipient_user_id: 'user-b',
    action_route: null,
  });
  expectTrue(withoutRoute.action_route === '', 'nullable route must not navigate');
});

Deno.test('claimed queue lease validation accepts only a complete matching batch', () => {
  const claimed = [
    { id: 'a', claim_token: 'token-a' },
    { id: 'b', claim_token: 'token-b' },
  ];
  expectTrue(claimedQueueMatches(claimed, [...claimed].reverse()), 'matching reordered queue should pass');
  expectTrue(!claimedQueueMatches(claimed, [claimed[0]]), 'missing queue row must fail');
  expectTrue(!claimedQueueMatches(claimed, [claimed[0], claimed[0]]), 'duplicate queue row must fail');
  expectTrue(!claimedQueueMatches(claimed, [
    claimed[0], { id: 'b', claim_token: 'stale-token' },
  ]), 'superseded lease must fail');
  expectTrue(!claimedQueueMatches([claimed[0], claimed[0]], claimed), 'duplicate claim must fail');
  expectTrue(!claimedQueueMatches(
    [{ id: 'a', claim_token: '' }],
    [{ id: 'a', claim_token: '' }],
  ), 'empty token must fail');
  expectTrue(claimedQueueMatches([], []), 'zero queue rows should match zero claims');
});
