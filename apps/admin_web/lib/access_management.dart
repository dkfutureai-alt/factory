import 'package:factoryos_core/factoryos_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccessManagementPage extends StatefulWidget {
  const AccessManagementPage({
    required this.organizationId,
    required this.actorRole,
    required this.factories,
    super.key,
  });

  final String organizationId;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<AccessManagementPage> createState() => _AccessManagementPageState();
}

class _AccessManagementPageState extends State<AccessManagementPage> {
  late Future<AccessSnapshot> future;

  AccessRepository get repository => AccessRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    future = repository.load(widget.organizationId);
  }

  void reload() =>
      setState(() => future = repository.load(widget.organizationId));

  Future<void> inviteUser() async {
    final draft = await showDialog<InviteDraft>(
      context: context,
      builder: (_) => InviteUserDialog(factories: widget.factories),
    );
    if (draft == null || !mounted) return;

    try {
      await repository.invite(widget.organizationId, draft);
      if (!mounted) return;
      _message('Invitation sent.');
      reload();
    } catch (error) {
      if (!mounted) return;
      _message(_errorText(error), isError: true);
    }
  }

  Future<void> editMember(AccessMember member) async {
    final draft = await showDialog<MemberAccessDraft>(
      context: context,
      builder: (_) => MemberAccessDialog(
        member: member,
        actorRole: widget.actorRole,
        factories: widget.factories,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      await repository.updateMember(
        widget.organizationId,
        member.userId,
        draft,
      );
      if (!mounted) return;
      _message('Access updated.');
      reload();
    } catch (error) {
      if (!mounted) return;
      _message(_errorText(error), isError: true);
    }
  }

  Future<void> deactivateMember(AccessMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate user access?'),
        content: Text(
          '${member.displayName} will lose organization and factory access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repository.deactivateMember(widget.organizationId, member.userId);
      if (!mounted) return;
      _message('User access deactivated.');
      reload();
    } catch (error) {
      if (!mounted) return;
      _message(_errorText(error), isError: true);
    }
  }

  Future<void> revokeInvitation(InvitationRow invitation) async {
    try {
      await repository.revokeInvitation(invitation.id);
      if (!mounted) return;
      _message('Invitation revoked.');
      reload();
    } catch (error) {
      if (!mounted) return;
      _message(_errorText(error), isError: true);
    }
  }

  void _message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccessSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: '${snapshot.error}', onRetry: reload);
        }
        final data = snapshot.requireData;
        return ListView(
          padding: const EdgeInsets.all(FactorySpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Users & Access',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: FactorySpacing.xs),
                      const Text(
                        'Invite users, assign roles and control factory access.',
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: inviteUser,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Invite user'),
                ),
              ],
            ),
            const SizedBox(height: FactorySpacing.lg),
            _Section(
              title: 'Active users',
              child: data.members.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(FactorySpacing.md),
                      child: Text('No users found.'),
                    )
                  : Column(
                      children: data.members.map((member) {
                        final names = _factoryNames(
                          member.factoryIds,
                          widget.factories,
                        );
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(_initials(member.displayName)),
                          ),
                          title: Text(member.displayName),
                          subtitle: Text(
                            [
                              member.email,
                              member.role.label,
                              if (names.isNotEmpty) names.join(', '),
                              if (!member.isActive) 'Inactive',
                            ].join(' · '),
                          ),
                          trailing: Wrap(
                            spacing: FactorySpacing.xs,
                            children: [
                              IconButton(
                                tooltip: 'Edit access',
                                onPressed: () => editMember(member),
                                icon: const Icon(
                                  Icons.manage_accounts_outlined,
                                ),
                              ),
                              if (member.isActive)
                                IconButton(
                                  tooltip: 'Deactivate',
                                  onPressed: () => deactivateMember(member),
                                  icon: const Icon(Icons.person_off_outlined),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: FactorySpacing.lg),
            _Section(
              title: 'Invitations',
              child: data.invitations.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(FactorySpacing.md),
                      child: Text('No invitations yet.'),
                    )
                  : Column(
                      children: data.invitations.map((invitation) {
                        final active =
                            invitation.status == 'pending' ||
                            invitation.status == 'sent';
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.mail_outline),
                          ),
                          title: Text(
                            invitation.fullName.isEmpty
                                ? invitation.email
                                : invitation.fullName,
                          ),
                          subtitle: Text(
                            '${invitation.email} · ${invitation.role.label} · ${invitation.status} · expires ${_shortDate(invitation.expiresAt)}',
                          ),
                          trailing: active
                              ? TextButton(
                                  onPressed: () => revokeInvitation(invitation),
                                  child: const Text('Revoke'),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class AccessRepository {
  AccessRepository(this.client);
  final SupabaseClient client;

  Future<AccessSnapshot> load(String organizationId) async {
    final memberData = await client.rpc(
      'list_organization_members',
      params: {'p_organization_id': organizationId},
    );
    final invitationData = await client
        .from('user_invitations')
        .select('id,email,full_name,role,status,expires_at,created_at')
        .eq('organization_id', organizationId)
        .order('created_at', ascending: false)
        .limit(30);

    final members = (memberData as List<dynamic>)
        .map(
          (row) => AccessMember.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    final invitations = invitationData
        .map((row) => InvitationRow.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    return AccessSnapshot(members: members, invitations: invitations);
  }

  Future<void> invite(String organizationId, InviteDraft draft) async {
    final response = await client.functions.invoke(
      'invite-user',
      body: {
        'organization_id': organizationId,
        'email': draft.email.trim(),
        'full_name': draft.fullName.trim(),
        'phone': draft.phone.trim(),
        'role': draft.role.wireName,
        'factory_ids': draft.factoryIds,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      if (data is Map && data['error'] != null)
        throw StateError('${data['error']}');
      throw StateError('Invitation failed with status ${response.status}.');
    }
  }

  Future<void> updateMember(
    String organizationId,
    String userId,
    MemberAccessDraft draft,
  ) async {
    await client.rpc(
      'update_member_access',
      params: {
        'p_organization_id': organizationId,
        'p_user_id': userId,
        'p_role': draft.role.wireName,
        'p_factory_ids': draft.factoryIds,
      },
    );
  }

  Future<void> deactivateMember(String organizationId, String userId) async {
    await client.rpc(
      'deactivate_organization_member',
      params: {'p_organization_id': organizationId, 'p_user_id': userId},
    );
  }

  Future<void> revokeInvitation(String invitationId) async {
    await client
        .from('user_invitations')
        .update({'status': 'revoked'})
        .eq('id', invitationId);
  }
}

class AccessSnapshot {
  const AccessSnapshot({required this.members, required this.invitations});
  final List<AccessMember> members;
  final List<InvitationRow> invitations;
}

class AccessMember {
  const AccessMember({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.factoryIds,
  });

  factory AccessMember.fromMap(Map<String, dynamic> map) {
    return AccessMember(
      userId: map['user_id'] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: AppRole.fromWireName(map['role'] as String? ?? 'viewer'),
      isActive: map['is_active'] as bool? ?? false,
      factoryIds: (map['factory_ids'] as List<dynamic>? ?? const [])
          .map((value) => '$value')
          .toList(),
    );
  }

  final String userId;
  final String email;
  final String fullName;
  final String phone;
  final AppRole role;
  final bool isActive;
  final List<String> factoryIds;

  String get displayName => fullName.trim().isEmpty ? email : fullName;
}

class InvitationRow {
  const InvitationRow({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.expiresAt,
  });

  factory InvitationRow.fromMap(Map<String, dynamic> map) => InvitationRow(
    id: map['id'] as String,
    email: map['email'] as String,
    fullName: map['full_name'] as String? ?? '',
    role: AppRole.fromWireName(map['role'] as String? ?? 'viewer'),
    status: map['status'] as String? ?? 'pending',
    expiresAt: DateTime.parse(map['expires_at'] as String),
  );

  final String id;
  final String email;
  final String fullName;
  final AppRole role;
  final String status;
  final DateTime expiresAt;
}

class InviteDraft {
  const InviteDraft({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.factoryIds,
  });
  final String fullName;
  final String email;
  final String phone;
  final AppRole role;
  final List<String> factoryIds;
}

class MemberAccessDraft {
  const MemberAccessDraft({required this.role, required this.factoryIds});
  final AppRole role;
  final List<String> factoryIds;
}

class InviteUserDialog extends StatefulWidget {
  const InviteUserDialog({required this.factories, super.key});
  final List<Map<String, dynamic>> factories;

  @override
  State<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<InviteUserDialog> {
  final formKey = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  AppRole role = AppRole.employee;
  final selectedFactories = <String>{};

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = AppRole.values
        .where((item) => item != AppRole.platformOwner)
        .toList();
    return AlertDialog(
      title: const Text('Invite new user'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: fullName,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: _nameValidator,
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: _emailValidator,
                ),
                const SizedBox(height: FactorySpacing.sm),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
                const SizedBox(height: FactorySpacing.sm),
                DropdownButtonFormField<AppRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    role = value ?? AppRole.employee;
                    if (!role.requiresFactoryAssignment)
                      selectedFactories.clear();
                  }),
                ),
                if (role.requiresFactoryAssignment) ...[
                  const SizedBox(height: FactorySpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Assign factories',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final factory in widget.factories)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selectedFactories.contains(factory['id']),
                      title: Text(factory['name'] as String),
                      subtitle: Text(factory['code'] as String),
                      onChanged: (checked) => setState(() {
                        final id = factory['id'] as String;
                        if (checked ?? false) {
                          selectedFactories.add(id);
                        } else {
                          selectedFactories.remove(id);
                        }
                      }),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            if (role.requiresFactoryAssignment && selectedFactories.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Select at least one factory for this role.'),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              InviteDraft(
                fullName: fullName.text,
                email: email.text,
                phone: phone.text,
                role: role,
                factoryIds: selectedFactories.toList(),
              ),
            );
          },
          child: const Text('Send invitation'),
        ),
      ],
    );
  }
}

class MemberAccessDialog extends StatefulWidget {
  const MemberAccessDialog({
    required this.member,
    required this.actorRole,
    required this.factories,
    super.key,
  });
  final AccessMember member;
  final AppRole actorRole;
  final List<Map<String, dynamic>> factories;

  @override
  State<MemberAccessDialog> createState() => _MemberAccessDialogState();
}

class _MemberAccessDialogState extends State<MemberAccessDialog> {
  late AppRole role;
  late Set<String> selectedFactories;

  @override
  void initState() {
    super.initState();
    role = widget.member.role;
    selectedFactories = widget.member.factoryIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final roles = AppRole.values
        .where(
          (item) =>
              item != AppRole.platformOwner ||
              widget.actorRole == AppRole.platformOwner,
        )
        .toList();
    return AlertDialog(
      title: Text('Access · ${widget.member.displayName}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AppRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: roles
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  role = value ?? role;
                  if (!role.requiresFactoryAssignment)
                    selectedFactories.clear();
                }),
              ),
              if (role.requiresFactoryAssignment) ...[
                const SizedBox(height: FactorySpacing.md),
                for (final factory in widget.factories)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selectedFactories.contains(factory['id']),
                    title: Text(factory['name'] as String),
                    subtitle: Text(factory['code'] as String),
                    onChanged: (checked) => setState(() {
                      final id = factory['id'] as String;
                      if (checked ?? false) {
                        selectedFactories.add(id);
                      } else {
                        selectedFactories.remove(id);
                      }
                    }),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (role.requiresFactoryAssignment && selectedFactories.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Select at least one factory for this role.'),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              MemberAccessDraft(
                role: role,
                factoryIds: selectedFactories.toList(),
              ),
            );
          },
          child: const Text('Save access'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(FactorySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Divider(),
          child,
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FactorySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: FactorySpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: FactorySpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((item) => item[0].toUpperCase()).join();
}

String _shortDate(DateTime value) =>
    value.toLocal().toString().split('.').first;

List<String> _factoryNames(
  List<String> ids,
  List<Map<String, dynamic>> factories,
) {
  final names = <String>[];
  for (final id in ids) {
    for (final factory in factories) {
      if (factory['id'] == id) names.add(factory['name'] as String);
    }
  }
  return names;
}

String? _nameValidator(String? value) =>
    (value?.trim().length ?? 0) < 2 ? 'Enter a full name.' : null;
String? _emailValidator(String? value) =>
    !(value?.contains('@') ?? false) ? 'Enter a valid email.' : null;
String _errorText(Object error) =>
    error is PostgrestException ? error.message : '$error';
