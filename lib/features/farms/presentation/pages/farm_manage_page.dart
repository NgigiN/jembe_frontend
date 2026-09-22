import 'package:farm_tracker/core/di/service_locator.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_invitation.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_member.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_transfer.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FarmManagePage extends StatefulWidget {
  const FarmManagePage({super.key});

  @override
  State<FarmManagePage> createState() => _FarmManagePageState();
}

class _FarmManagePageState extends State<FarmManagePage> {
  List<FarmMember> _members = [];
  List<FarmInvitation> _invitations = [];
  FarmTransfer? _transfer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final remote = sl<FarmRemoteDataSource>();
    final members = await remote.listMembers();
    final invitations = await remote.listInvitations();
    final transfer = await remote.getTransfer();
    if (!mounted) return;
    setState(() {
      _members = members;
      _invitations = invitations;
      _transfer = transfer;
      _loading = false;
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(context, 'That action could not be completed. Try again.'),
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
                  DropdownMenuItem(value: FarmRole.worker, child: Text('Worker')),
                  DropdownMenuItem(value: FarmRole.manager, child: Text('Manager')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => role = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Invite')),
          ],
        ),
      ),
    );
    if (invited ?? false) {
      await _runAction(() => sl<FarmRemoteDataSource>().createInvitation(emailController.text, role));
    }
  }

  Future<void> _showNominateDialog() async {
    final managers = _members.where((m) => m.role == FarmRole.manager).toList();
    if (managers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(context, 'Promote a member to manager first — only a manager can be nominated.'),
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
      await _runAction(() => sl<FarmRemoteDataSource>().nominateTransfer(chosen.userId));
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                for (final member in _members)
                  ListTile(
                    title: Text(member.fullName),
                    subtitle: Text('${member.email} · ${member.role.wireValue}'),
                    trailing: isStaff && member.role != FarmRole.owner
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<FarmRole>(
                                tooltip: 'Change role',
                                icon: const Icon(Icons.swap_horiz),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: FarmRole.manager, child: Text('Manager')),
                                  PopupMenuItem(value: FarmRole.worker, child: Text('Worker')),
                                ],
                                onSelected: (newRole) => _runAction(
                                  () => sl<FarmRemoteDataSource>().updateMemberRole(member.userId, newRole),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Remove',
                                onPressed: () => _runAction(
                                  () => sl<FarmRemoteDataSource>().removeMember(member.userId),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                if (isStaff) ...[
                  const SizedBox(height: 24),
                  Text('Pending Invitations', style: Theme.of(context).textTheme.titleMedium),
                  for (final invitation in _invitations)
                    ListTile(
                      title: Text(invitation.email),
                      subtitle: Text(invitation.role.wireValue),
                      trailing: IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: 'Revoke',
                        onPressed: () => _runAction(
                          () => sl<FarmRemoteDataSource>().revokeInvitation(invitation.id),
                        ),
                      ),
                    ),
                ],
                if (isOwner) ...[
                  const SizedBox(height: 24),
                  Text('Ownership', style: Theme.of(context).textTheme.titleMedium),
                  ListTile(
                    title: Text(_transfer == null ? 'No pending transfer' : 'Transfer pending'),
                    subtitle: const Text('Nominate a manager to become the new owner'),
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
                            onPressed: () => _runAction(() => sl<FarmRemoteDataSource>().cancelTransfer()),
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}
