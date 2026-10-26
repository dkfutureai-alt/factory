/** Pure, testable, input validation for the invitation Edge Function. */
export type InviteRequest = {
  organizationId: string; email: string; fullName: string; phone: string | null;
  role: string; factoryIds: string[];
};
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const roles = new Set(['org_admin','factory_manager','supervisor','employee','driver','viewer']);
export class InviteInputError extends Error {
  constructor(message: string) { super(message); this.name = 'InviteInputError'; }
}
export function parseInviteRequest(input: unknown): InviteRequest {
  if (typeof input !== 'object' || input === null || Array.isArray(input)) {
    throw new InviteInputError('A JSON invitation object is required');
  }
  const body = input as Record<string, unknown>;
  const value = (key: string): string => {
    if (typeof body[key] !== 'string') throw new InviteInputError(`${key} must be a string`);
    return (body[key] as string).trim();
  };
  const organizationId = value('organization_id').toLowerCase();
  const email = value('email').toLowerCase();
  const fullName = value('full_name');
  const role = value('role');
  const phoneInput = body.phone;
  if (!uuidPattern.test(organizationId)) throw new InviteInputError('Invalid organization ID');
  if (email.length > 254 || !emailPattern.test(email)) throw new InviteInputError('A valid email address is required');
  if (fullName.length < 2 || fullName.length > 120) throw new InviteInputError('Full name must be 2–120 characters');
  if (!roles.has(role)) throw new InviteInputError('Invalid invitation role');
  if (phoneInput !== undefined && phoneInput !== null && typeof phoneInput !== 'string') throw new InviteInputError('Phone must be a string');
  const phone = typeof phoneInput === 'string' ? phoneInput.trim() || null : null;
  if (phone && phone.length > 32) throw new InviteInputError('Phone is too long');
  const rawIds = body.factory_ids ?? [];
  if (!Array.isArray(rawIds) || rawIds.length > 100) throw new InviteInputError('factory_ids must be an array of up to 100 factory IDs');
  const factoryIds = [...new Set(rawIds.map((id: unknown) => {
    if (typeof id !== 'string' || !uuidPattern.test(id)) throw new InviteInputError('Invalid factory ID');
    return id.toLowerCase();
  }))];
  if (['factory_manager','supervisor','employee','driver'].includes(role) && factoryIds.length === 0) throw new InviteInputError('This role requires at least one factory assignment');
  return { organizationId, email, fullName, phone, role, factoryIds };
}
export function resolveInviteRedirect(configured: string | undefined, supabaseUrl: string): string | null {
  let backend: URL;
  try { backend = new URL(supabaseUrl); } catch { return null; }
  const local = backend.protocol === 'http:' && ['localhost','127.0.0.1'].includes(backend.hostname);
  const candidate = configured?.trim() || (local ? 'http://localhost:3000' : '');
  if (!candidate) return null;
  try {
    const redirect = new URL(candidate);
    if (redirect.username || redirect.password || redirect.hash || redirect.origin === 'null') return null;
    if (local && redirect.protocol === 'http:' && ['localhost','127.0.0.1'].includes(redirect.hostname)) return redirect.toString();
    if (redirect.protocol !== 'https:') return null;
    if (!redirect.hostname || ['localhost','127.0.0.1','0.0.0.0','[::1]'].includes(redirect.hostname) || redirect.hostname.endsWith('.localhost')) return null;
    return redirect.toString();
  } catch { return null; }
}
