import { createClient } from 'npm:@supabase/supabase-js@2';
import { InviteInputError, parseInviteRequest, resolveInviteRedirect } from './invite_helpers.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
    if (!supabaseUrl || !serviceRoleKey) return json(503, { error: 'Invitation service not configured' });
    if (!authHeader.startsWith('Bearer ')) return json(401, { error: 'Authentication required' });
    const redirectTo = resolveInviteRedirect(Deno.env.get('FACTORYOS_INVITE_REDIRECT_URL'), supabaseUrl);
    if (!redirectTo) return json(503, { error: 'Invitation redirect not configured securely' });

    const service = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const token = authHeader.slice('Bearer '.length);
    const { data: authData, error: authError } = await service.auth.getUser(token);
    if (authError || !authData.user) return json(401, { error: 'Invalid session' });

    let body: unknown;
    try { body = await req.json(); }
    catch { return json(400, { error: 'A valid JSON invitation body is required' }); }
    let invite;
    try { invite = parseInviteRequest(body); }
    catch (error) {
      if (error instanceof InviteInputError) return json(400, { error: error.message });
      throw error;
    }
    const { organizationId, email, fullName, phone, role, factoryIds } = invite;

    const { data: ownerMembership, error: ownerError } = await service
      .from('organization_members')
      .select('role')
      .eq('user_id', authData.user.id)
      .eq('role', 'platform_owner')
      .eq('is_active', true)
      .limit(1)
      .maybeSingle();
    if (ownerError) throw ownerError;
    const isPlatformOwner = ownerMembership?.role === 'platform_owner';

    const { data: orgMembership, error: orgError } = await service
      .from('organization_members')
      .select('role')
      .eq('organization_id', organizationId)
      .eq('user_id', authData.user.id)
      .eq('is_active', true)
      .maybeSingle();
    if (orgError) throw orgError;
    const isOrgAdmin = orgMembership?.role === 'org_admin';
    if (!isPlatformOwner && !isOrgAdmin) return json(403, { error: 'Organization admin access required' });

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

    // Free the partial unique email constraint only for this organization's expired invites.
    // Migration 0043 must precede deployment of this Edge Function.
    const { error: expiryError } = await service.rpc('expire_stale_user_invitations', {
      p_organization_id: organizationId, p_email: email,
    });
    if (expiryError) throw expiryError;

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
      if (assignmentError) {
        const { error: cleanupError } = await service.from('user_invitations')
          .update({ status: 'failed' }).eq('id', invitation.id).eq('status', 'pending');
        if (cleanupError) console.error('Could not release failed factory invitation');
        throw assignmentError;
      }
    }

    const { data: invited, error: inviteError } = await service.auth.admin.inviteUserByEmail(email, {
      redirectTo,
      data: {
        factoryos_invitation_id: invitation.id,
        factoryos_organization_id: organizationId,
      },
    });

    if (inviteError) {
      const { error: stateError } = await service.from('user_invitations')
        .update({ status: 'failed', delivery_error: inviteError.message })
        .eq('id', invitation.id);
      if (stateError) console.error('Could not record invitation mail failure');
      return json(502, { error: 'Invitation email delivery failed. Check email settings and retry.' });
    }

    const { error: sentError } = await service.from('user_invitations')
      .update({ status: 'sent', auth_user_id: invited.user?.id ?? null, delivery_error: null })
      .eq('id', invitation.id);
    if (sentError) throw sentError;

    return json(200, { invitation_id: invitation.id, status: 'sent' });
  } catch (error) {
    console.error('Invitation failed', error instanceof Error ? error.name : 'unknown error');
    return json(500, { error: 'Invitation could not be completed. Please retry or contact support.' });
  }
});
