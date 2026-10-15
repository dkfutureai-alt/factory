import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type InviteBody = {
  organization_id?: string;
  email?: string;
  full_name?: string;
  phone?: string;
  role?: string;
  factory_ids?: string[];
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' });

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!supabaseUrl || !serviceRoleKey || !authHeader.startsWith('Bearer ')) {
      return json(401, { error: 'Authentication required' });
    }

    const service = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const token = authHeader.slice('Bearer '.length);
    const { data: authData, error: authError } = await service.auth.getUser(token);
    if (authError || !authData.user) return json(401, { error: 'Invalid session' });

    const body = (await req.json()) as InviteBody;
    const organizationId = body.organization_id?.trim() ?? '';
    const email = body.email?.trim().toLowerCase() ?? '';
    const fullName = body.full_name?.trim() ?? '';
    const phone = body.phone?.trim() || null;
    const role = body.role?.trim() ?? '';
    const factoryIds = [...new Set(body.factory_ids ?? [])];

    if (!organizationId || !email.includes('@') || fullName.length < 2 || !role) {
      return json(400, { error: 'Organization, valid email, full name and role are required' });
    }

    const allowedRoles = ['org_admin', 'factory_manager', 'supervisor', 'employee', 'driver', 'viewer'];
    if (!allowedRoles.includes(role)) return json(400, { error: 'Invalid invitation role' });

    const { data: ownerMembership } = await service
      .from('organization_members')
      .select('role')
      .eq('user_id', authData.user.id)
      .eq('role', 'platform_owner')
      .eq('is_active', true)
      .limit(1)
      .maybeSingle();
    const isPlatformOwner = ownerMembership?.role === 'platform_owner';

    const { data: orgMembership } = await service
      .from('organization_members')
      .select('role')
      .eq('organization_id', organizationId)
      .eq('user_id', authData.user.id)
      .eq('is_active', true)
      .maybeSingle();
    const isOrgAdmin = orgMembership?.role === 'org_admin';
    if (!isPlatformOwner && !isOrgAdmin) return json(403, { error: 'Organization admin access required' });

    const factoryRole = ['factory_manager', 'supervisor', 'employee', 'driver'].includes(role);
    if (factoryRole && factoryIds.length === 0) {
      return json(400, { error: 'This role requires at least one factory assignment' });
    }

    if (factoryIds.length > 0) {
      const { data: validFactories, error: factoryError } = await service
        .from('factories')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .in('id', factoryIds);
      if (factoryError) throw factoryError;
      if ((validFactories ?? []).length !== factoryIds.length) {
        return json(400, { error: 'One or more factory assignments are invalid' });
      }
    }

    const { data: invitation, error: invitationError } = await service
      .from('user_invitations')
      .insert({
        organization_id: organizationId,
        email,
        full_name: fullName,
        phone,
        role,
        status: 'pending',
        invited_by: authData.user.id,
      })
      .select('id')
      .single();
    if (invitationError) {
      if (invitationError.code === '23505') return json(409, { error: 'An active invitation already exists for this email' });
      throw invitationError;
    }

    if (factoryIds.length > 0) {
      const { error: assignmentError } = await service.from('user_invitation_factories').insert(
        factoryIds.map((factoryId) => ({
          invitation_id: invitation.id,
          organization_id: organizationId,
          factory_id: factoryId,
        })),
      );
      if (assignmentError) throw assignmentError;
    }

    const redirectTo = Deno.env.get('FACTORYOS_INVITE_REDIRECT_URL') ?? 'http://localhost:3000';
    const { data: invited, error: inviteError } = await service.auth.admin.inviteUserByEmail(email, {
      redirectTo,
      data: {
        factoryos_invitation_id: invitation.id,
        factoryos_organization_id: organizationId,
      },
    });

    if (inviteError) {
      await service
        .from('user_invitations')
        .update({ status: 'failed', delivery_error: inviteError.message })
        .eq('id', invitation.id);
      return json(400, { error: inviteError.message });
    }

    await service
      .from('user_invitations')
      .update({ status: 'sent', auth_user_id: invited.user?.id ?? null, delivery_error: null })
      .eq('id', invitation.id);

    return json(200, { invitation_id: invitation.id, status: 'sent' });
  } catch (error) {
    console.error(error);
    return json(500, { error: error instanceof Error ? error.message : 'Invitation failed' });
  }
});
