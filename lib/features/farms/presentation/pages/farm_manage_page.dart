import 'dart:async';

import 'package:farm_tracker/core/di/service_locator.dart';
import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/navigation/app_route_path.dart';
import 'package:farm_tracker/core/widgets/crud/entity_error_view.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/billing/presentation/widgets/read_only_banner.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_invitation.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_member.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_transfer.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// What to do when an invitation fails.
enum InviteFailure { paywall, message }

/// A 402 means the owner's plan does not cover another person, and the only
/// useful response is to show them what it costs. Everything else - already a
/// member, a pending invitation, a bad address, no network - is a message on
/// the page they are already on.
InviteFailure inviteFailureAction(Object error) {
  return error is PaymentRequiredException
      ? InviteFailure.paywall
      : InviteFailure.message;
}

class FarmManagePage extends StatefulWidget {
  const FarmManagePage({super.key, this.remote});

  /// Overrides the shared global `sl<FarmRemoteDataSource>()` lookup this
  /// page otherwise falls back to. Mobile call sites omit this (unchanged
  /// behavior, resolves via `sl`, which lib/injection_container.dart
  /// populates); the web console passes its own `webSl<FarmRemoteDataSource>()`
  /// explicitly instead of also registering onto the shared `sl` just for
  /// this page to read from (web-console final-review finding I10).
  final FarmRemoteDataSource? remote;

  @override
  State<FarmManagePage> createState() => _FarmManagePageState();
}

class _FarmManagePageState extends State<FarmManagePage> {
  late final FarmRemoteDataSource _remote =
      widget.remote ?? sl<FarmRemoteDataSource>();
  List<FarmMember> _members = [];
  List<FarmInvitation> _invitations = [];
  FarmTransfer? _transfer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads members, invitations and the pending transfer.
  ///
  /// The failure path matters more than the success one here. This used to
  /// await three calls with no catch and clear [_loading] only after the last
  /// one returned, so a single failure left the page spinning forever — and
  /// because [initState] calls this without awaiting it, the exception went
  /// nowhere anyone would see. On the page people use to invite someone.
  ///
  /// [_loading] is cleared in a `finally` deliberately: a later edit that adds
  /// an early return cannot then reintroduce the permanent spinner.
  Future<void> _load() async {
    final remote = _remote;
    if (mounted) setState(() => _error = null);
    try {
      final members = await remote.listMembers();
      final invitations = await remote.listInvitations();
      final transfer = await remote.getTransfer();
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _transfer = transfer;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error =
            'We could not load this farm. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(
          context,
          'That action could not be completed. Try again.',
        ),
      );
    }
  }

  Future<void> _showInviteDialog() async {
    final emailController = TextEditingController();
    var role = FarmRole.worker;
    final invited = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Invite a Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              DropdownButton<FarmRole>(
                value: role,
                items: const [
                  DropdownMenuItem(
                    value: FarmRole.worker,
                    child: Text('Worker'),
                  ),
                  DropdownMenuItem(
                    value: FarmRole.manager,
                    child: Text('Manager'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => role = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );
    if (invited ?? false) {
      await _inviteAndReport(emailController.text, role);
    }
  }

  /// Invites, then says what became of the email.
  ///
  /// Previously this path reported nothing at all on success: the new row just
  /// appeared in the pending list, which reads as "sent" while no invitation
  /// email existed anywhere in the product. Saying so plainly is the point —
  /// the invite is claimed by signing in with the invited address, so when no
  /// mail goes out somebody has to tell the person.
  Future<void> _inviteAndReport(String email, FarmRole role) async {
    try {
      final invitation = await _remote.createInvitation(email, role);
      await _load();
      if (!mounted) return;
      final emailed = invitation.emailSent ?? false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          emailed
              ? AppSnackBar.success(
                  context,
                  'Invited $email — we emailed them how to join.',
                )
              : AppSnackBar.info(
                  context,
                  'Invited $email. No email was sent, so ask them to sign in '
                  'with that address.',
                ),
        );
    } catch (e) {
      if (!mounted) return;
      if (inviteFailureAction(e) == InviteFailure.paywall) {
        await context.push(AppRoutePath.paywall);
        // They may have paid while they were away. Reload so the member and
        // invitation lists reflect whatever changed.
        if (mounted) await _load();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(
          context,
          'That action could not be completed. Try again.',
        ),
      );
    }
  }

  Future<void> _showNominateDialog() async {
    final managers = _members.where((m) => m.role == FarmRole.manager).toList();
    if (managers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(
          context,
          'Promote a member to manager first — only a manager can be nominated.',
        ),
      );
      return;
    }
    final chosen = await showDialog<FarmMember>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Nominate a Successor'),
        children: [
          for (final manager in managers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, manager),
              child: Text(manager.fullName),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await _runAction(() => _remote.nominateTransfer(chosen.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmState = context.watch<FarmBloc>().state;
    final role = farmState is FarmLoaded ? farmState.currentRole : null;
    final isStaff = role?.isStaff ?? false;
    final isOwner = role == FarmRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Farm'),
        actions: [
          if (isStaff)
            IconButton(
              key: const Key('invite_member_button'),
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite a Member',
              onPressed: _showInviteDialog,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? EntityErrorView(
              message: _error!,
              onRetry: () {
                setState(() => _loading = true);
                unawaited(_load());
              },
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ReadOnlyBanner(),
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                for (final member in _members)
                  ListTile(
                    title: Text(member.fullName),
                    subtitle: Text(
                      '${member.email} · ${member.role.wireValue}',
                    ),
                    trailing: isStaff && member.role != FarmRole.owner
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<FarmRole>(
                                tooltip: 'Change role',
                                icon: const Icon(Icons.swap_horiz),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: FarmRole.manager,
                                    child: Text('Manager'),
                                  ),
                                  PopupMenuItem(
                                    value: FarmRole.worker,
                                    child: Text('Worker'),
                                  ),
                                ],
                                onSelected: (newRole) => _runAction(
                                  () => _remote.updateMemberRole(
                                    member.userId,
                                    newRole,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Remove',
                                onPressed: () => _runAction(
                                  () => _remote.removeMember(member.userId),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                if (isStaff) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Pending Invitations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final invitation in _invitations)
                    ListTile(
                      title: Text(invitation.email),
                      subtitle: Text(invitation.role.wireValue),
                      trailing: IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: 'Revoke',
                        onPressed: () => _runAction(
                          () => _remote.revokeInvitation(invitation.id),
                        ),
                      ),
                    ),
                ],
                if (isOwner) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Ownership',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ListTile(
                    title: Text(
                      _transfer == null
                          ? 'No pending transfer'
                          : 'Transfer pending',
                    ),
                    subtitle: const Text(
                      'Nominate a manager to become the new owner',
                    ),
                    trailing: _transfer == null
                        ? IconButton(
                            key: const Key('nominate_transfer_button'),
                            icon: const Icon(Icons.swap_horiz),
                            tooltip: 'Nominate Successor',
                            onPressed: _showNominateDialog,
                          )
                        : IconButton(
                            key: const Key('cancel_transfer_button'),
                            icon: const Icon(Icons.cancel_outlined),
                            tooltip: 'Cancel Transfer',
                            onPressed: () =>
                                _runAction(() => _remote.cancelTransfer()),
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}
