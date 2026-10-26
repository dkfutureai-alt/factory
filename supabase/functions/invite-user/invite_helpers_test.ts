import { InviteInputError, parseInviteRequest, resolveInviteRedirect } from './invite_helpers.ts';
const organization = '31000000-0000-4000-8000-000000000001';
const factory = '32000000-0000-4000-8000-000000000001';
const valid = () => ({ organization_id: organization, email: ' WORKER@Example.com ', full_name: ' Test Worker ', role: 'employee', factory_ids: [factory, factory.toUpperCase()] });
function ok(condition: boolean, message: string) { if (!condition) throw new Error(message); }
function fails(body: unknown) {
  try { parseInviteRequest(body); } catch(e) { ok(e instanceof InviteInputError, 'Unexpected error type'); return; }
  throw new Error('Expected bad input to be rejected');
}
Deno.test('normalizes and deduplicates', () => {
  const result = parseInviteRequest(valid());
  ok(result.email === 'worker@example.com','Email normalization');
  ok(result.fullName === 'Test Worker','Name trim');
  ok(result.factoryIds.length === 1 && result.factoryIds[0] === factory,'Factory ID deduplication');
});
Deno.test('rejects untrusted body', () => {
  fails(null); fails([]); fails('hello'); fails({...valid(),factory_ids:'a string'});
  fails({...valid(),factory_ids:[null]}); fails({...valid(),factory_ids:[]});
  fails({...valid(),email:'invalid'}); fails({...valid(),organization_id:'abc'});
  fails({...valid(),role:'platform_owner'}); fails({...valid(),full_name:'x'});
  fails({...valid(),phone:{number:'123'}});
});
Deno.test('viewer may have no factory', () => {
  ok(parseInviteRequest({...valid(),role:'viewer',factory_ids:undefined}).factoryIds.length === 0,'Viewer factories');
});
Deno.test('redirects fail closed in production', () => {
  const production = 'https://abcdefghijklmnopqrst.supabase.co';
  ok(resolveInviteRedirect(undefined,production) === null,'No localhost fallback');
  ok(resolveInviteRedirect('http://localhost:3000',production) === null,'Reject local HTTP');
  ok(resolveInviteRedirect('https://[::1]/',production) === null,'Reject IPv6 loopback');
  ok(resolveInviteRedirect('https://name:password@example.com',production) === null,'Reject URL credentials');
  ok(resolveInviteRedirect('https://factory.example.com/onboard',production) === 'https://factory.example.com/onboard','HTTPS allowed');
  ok(resolveInviteRedirect(undefined,'http://127.0.0.1:54321') === 'http://localhost:3000/','Local development');
});
