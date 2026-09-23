import 'package:farm_tracker/core/theme/app_typography.dart';
import 'package:farm_tracker/core/theme/console_colors.dart';
import 'package:farm_tracker/core/theme/console_metrics.dart';
import 'package:farm_tracker/core/theme/status_colors.dart';
import 'package:farm_tracker/core/utils/console_dates.dart';
import 'package:farm_tracker/core/widgets/feedback/app_snackbar.dart';
import 'package:farm_tracker/features/farms/data/datasources/farm_remote_data_source.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_invitation.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_member.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_transfer.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_bloc.dart';
import 'package:farm_tracker/features/farms/presentation/bloc/farm_state.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_card.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_dashed_border.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_empty.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_identity.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_page.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_skeleton.dart';
import 'package:farm_tracker/features/web_console/presentation/widgets/console_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Members (DESIGN_SPEC §4, screen 05): who can see and log on this farm.
///
/// Pending invitations are rows in the same table rather than a second
/// list below it — an invitation is a person on their way in, and reading
/// two lists to answer "who is on this farm" is the thing that design
/// avoids.
class WebMembersPage extends StatefulWidget {
  const WebMembersPage({required this.remote, super.key});

  final FarmRemoteDataSource remote;

  @override
  State<WebMembersPage> createState() => _WebMembersPageState();
}

class _WebMembersPageState extends State<WebMembersPage> {
  List<FarmMember>? _members;
  List<FarmInvitation> _invitations = const [];
  FarmTransfer? _transfer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await widget.remote.listMembers();
      final invitations = await widget.remote.listInvitations();
      final transfer = await widget.remote.getTransfer();
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _transfer = transfer;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(AppSnackBar.success(context, success));
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(context, "That didn't go through. Try again."),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmState = context.watch<FarmBloc>().state;
    final role = farmState is FarmLoaded ? farmState.currentRole : null;
    final farm = _currentFarm(farmState);

    return MembersView(
      farmName: farm?.name ?? 'Your farm',
      seats: farm?.maxMembers,
      role: role,
      members: _members,
      invitations: _invitations,
      transferPending: _transfer != null,
      errorMessage: _error,
      onRetry: _load,
      onInvite: (email, inviteRole) => _run(
        () => widget.remote.createInvitation(email, inviteRole),
        'Invitation sent to $email.',
      ),
      onResend: (invitation) => _run(
        () => widget.remote.createInvitation(invitation.email, invitation.role),
        'Invitation sent again to ${invitation.email}.',
      ),
      onRevoke: (invitation) => _run(
        () => widget.remote.revokeInvitation(invitation.id),
        'Invitation to ${invitation.email} revoked.',
      ),
      onRoleChange: (member, newRole) => _run(
        () => widget.remote.updateMemberRole(member.userId, newRole),
        '${member.fullName} is now a ${newRole.label.toLowerCase()}.',
      ),
      onRemove: (member) => _run(
        () => widget.remote.removeMember(member.userId),
        '${member.fullName} was removed from the farm.',
      ),
      onNominate: (member) => _run(
        () => widget.remote.nominateTransfer(member.userId),
        '${member.fullName} was nominated. They must accept before anything '
            'changes.',
      ),
      onCancelTransfer: () =>
          _run(widget.remote.cancelTransfer, 'Transfer cancelled.'),
    );
  }

  Farm? _currentFarm(FarmState state) {
    if (state is! FarmLoaded || state.currentFarmId == null) return null;
    for (final farm in state.farms) {
      if (farm.id == state.currentFarmId) return farm;
    }
    return null;
  }
}

/// The Members page's drawing, with no data source in sight.
class MembersView extends StatelessWidget {
  const MembersView({
    required this.farmName,
    required this.members,
    this.seats,
    this.role,
    this.invitations = const [],
    this.transferPending = false,
    this.errorMessage,
    this.onRetry,
    this.onInvite,
    this.onResend,
    this.onRevoke,
    this.onRoleChange,
    this.onRemove,
    this.onNominate,
    this.onCancelTransfer,
    super.key,
  });

  final String farmName;
  final int? seats;
  final FarmRole? role;

  /// Null while loading.
  final List<FarmMember>? members;

  final List<FarmInvitation> invitations;
  final bool transferPending;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final void Function(String email, FarmRole role)? onInvite;
  final void Function(FarmInvitation)? onResend;
  final void Function(FarmInvitation)? onRevoke;
  final void Function(FarmMember, FarmRole)? onRoleChange;
  final void Function(FarmMember)? onRemove;
  final void Function(FarmMember)? onNominate;
  final VoidCallback? onCancelTransfer;

  bool get _isStaff => role != null && role!.isStaff;
  bool get _isOwner => role == FarmRole.owner;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null && members == null) {
      return ConsoleErrorState(
        farmName: farmName,
        subtitle: 'Members',
        detail: errorMessage!,
        onRetry: onRetry,
      );
    }

    final owner = members?.where((m) => m.role == FarmRole.owner).firstOrNull;

    return ConsolePage(
      title: 'Members',
      subtitle: 'Who can see and log on $farmName',
      actions: [
        if (_isStaff)
          ConsoleButton.filled(
            label: 'Invite member',
            icon: Icons.person_add_alt,
            onPressed: onInvite == null
                ? null
                : () => _showInviteDialog(context),
          ),
      ],
      rail: _isStaff
          ? ConsoleRail(children: [InviteCard(onInvite: onInvite)])
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConsoleCard(
            title: 'Members',
            titleTrailing: Text(
              _meta(),
              style: AppTypography.meta.copyWith(color: context.console.muted),
            ),
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
            child: _table(context),
          ),
          if (_isOwner && owner != null) ...[
            const SizedBox(height: ConsoleMetrics.gridGap),
            _OwnershipBar(
              ownerName: owner.fullName,
              transferPending: transferPending,
              onNominate: () => _showNominateDialog(context),
              onCancel: onCancelTransfer,
            ),
          ],
          const SizedBox(height: 14),
          const _RoleLegend(),
        ],
      ),
    );
  }

  String _meta() {
    final active = members?.length ?? 0;
    return [
      '$active active',
      if (invitations.isNotEmpty) '${invitations.length} pending',
      if (seats != null) '$seats seats',
    ].join(' · ');
  }

  Widget _table(BuildContext context) {
    if (members == null) return const SkeletonRows(count: 4);
    if (members!.isEmpty) {
      return const ConsoleEmptyBlock(
        icon: Icons.group_outlined,
        title: 'No one here yet',
        body: 'Invite the people who work on this farm and they will show up '
            'here.',
      );
    }

    final console = context.console;

    return ConsoleTable(
      columns: [
        const ConsoleColumn('Name', flex: 4),
        const ConsoleColumn('Email', flex: 6),
        const ConsoleColumn('Role', width: 118),
        const ConsoleColumn('Joined', flex: 2),
        if (_isStaff) const ConsoleColumn('', width: 150, alignEnd: true),
      ],
      rows: [
        for (final member in members!) _memberRow(context, member),
        // A pending invitation is a person on their way in, so it sits in
        // the same table, tinted (DESIGN_SPEC §4).
        if (_isStaff)
          for (final invitation in invitations)
            _invitationRow(context, invitation, console),
      ],
    );
  }

  ConsoleRow _memberRow(BuildContext context, FarmMember member) {
    final console = context.console;
    final isOwnerRow = member.role == FarmRole.owner;

    return ConsoleRow([
      Row(
        children: [
          InitialsAvatar(member.fullName, size: 28, emphasised: isOwnerRow),
          const SizedBox(width: 10),
          Expanded(
            child: Text(member.fullName, style: AppTypography.cellStrong),
          ),
        ],
      ),
      Text(
        member.email,
        style: AppTypography.cell.copyWith(color: console.onSurface2),
        overflow: TextOverflow.ellipsis,
      ),
      if (_isStaff && !isOwnerRow && onRoleChange != null)
        _RoleMenu(
          member: member,
          onChanged: (newRole) => onRoleChange!(member, newRole),
        )
      else
        RoleTag(member.role),
      Text(
        formatDayMonth(member.joinedAt.toLocal()),
        style: AppTypography.cell.copyWith(color: console.muted),
      ),
      if (_isStaff && !isOwnerRow)
        _RowMenu(
          onRemove: onRemove == null ? null : () => onRemove!(member),
          onNominate: _isOwner && member.role == FarmRole.manager
              ? () => onNominate?.call(member)
              : null,
        )
      else if (_isStaff)
        const SizedBox.shrink(),
    ]);
  }

  ConsoleRow _invitationRow(
    BuildContext context,
    FarmInvitation invitation,
    ConsoleColors console,
  ) {
    final days = invitation.expiresAt.difference(DateTime.now()).inDays;

    return ConsoleRow(
      [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: DashedRoundedBorder(color: console.outline, radius: 14),
              ),
              child: Icon(
                Icons.mail_outline,
                size: 14,
                color: console.muted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Invitation sent',
                style: AppTypography.cellStrong.copyWith(color: console.muted),
              ),
            ),
          ],
        ),
        Text(
          invitation.email,
          style: AppTypography.cell.copyWith(color: console.onSurface2),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          invitation.role.label,
          style: AppTypography.cell.copyWith(color: console.muted),
        ),
        Text(
          days <= 0 ? 'Expired' : 'Expires in $days days',
          style: AppTypography.cell.copyWith(
            color: context.statusColors.warning,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onResend == null ? null : () => onResend!(invitation),
              style: _inlineTextButton(Theme.of(context).colorScheme.primary),
              child: const Text('Resend'),
            ),
            TextButton(
              onPressed: onRevoke == null ? null : () => onRevoke!(invitation),
              style: _inlineTextButton(Theme.of(context).colorScheme.error),
              child: const Text('Revoke'),
            ),
          ],
        ),
      ],
      tint: console.surfaceLow,
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final result = await showDialog<({String email, FarmRole role})>(
      context: context,
      builder: (context) => const _InviteDialog(),
    );
    if (result != null) onInvite?.call(result.email, result.role);
  }

  Future<void> _showNominateDialog(BuildContext context) async {
    final managers =
        members?.where((m) => m.role == FarmRole.manager).toList() ??
        const <FarmMember>[];
    if (managers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error(
          context,
          'Make someone a manager first — only a manager can take over.',
        ),
      );
      return;
    }
    final chosen = await showDialog<FarmMember>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Nominate a successor'),
        titleTextStyle: AppTypography.cardTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          for (final manager in managers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, manager),
              child: Row(
                children: [
                  InitialsAvatar(manager.fullName, size: 28),
                  const SizedBox(width: 10),
                  Text(manager.fullName, style: AppTypography.body),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen != null) onNominate?.call(chosen);
  }
}

/// Text buttons inside a table row are 31px, not the header's 36px
/// (DESIGN_SPEC §1, "Spacing").
ButtonStyle _inlineTextButton(Color foreground) => TextButton.styleFrom(
  foregroundColor: foreground,
  minimumSize: const Size(0, ConsoleMetrics.inlineButtonHeight),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  textStyle: AppTypography.cell.copyWith(fontWeight: FontWeight.w500),
);

/// The rail's invite panel (DESIGN_SPEC §4, screen 05).
class InviteCard extends StatefulWidget {
  const InviteCard({required this.onInvite, super.key});

  final void Function(String email, FarmRole role)? onInvite;

  @override
  State<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<InviteCard> {
  final _email = TextEditingController();
  FarmRole _role = FarmRole.worker;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return ConsoleCard(
      kicker: 'Invite by email',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: AppTypography.bodyDense,
            decoration: const InputDecoration(hintText: 'name@gmail.com'),
          ),
          const SizedBox(height: 10),
          _RoleSegment(
            value: _role,
            onChanged: (role) => setState(() => _role = role),
          ),
          const SizedBox(height: 10),
          ConsoleButton.filled(
            label: 'Send invitation',
            icon: Icons.send_outlined,
            onPressed: widget.onInvite == null
                ? null
                : () {
                    final email = _email.text.trim();
                    if (email.isEmpty) return;
                    widget.onInvite!(email, _role);
                    _email.clear();
                  },
          ),
          const SizedBox(height: 10),
          Text(
            "They'll get an email and see this farm in the Android app once "
            'they accept.',
            style: AppTypography.meta.copyWith(
              color: console.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The two-option role picker: what each role can do, stated on the option
/// itself rather than left to the reader (DESIGN_SPEC §4).
class _RoleSegment extends StatelessWidget {
  const _RoleSegment({required this.value, required this.onChanged});

  final FarmRole value;
  final ValueChanged<FarmRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleOption(
            role: FarmRole.worker,
            caption: 'Logs work only',
            selected: value == FarmRole.worker,
            onTap: () => onChanged(FarmRole.worker),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RoleOption(
            role: FarmRole.manager,
            caption: 'Sees reports, invites',
            selected: value == FarmRole.manager,
            onTap: () => onChanged(FarmRole.manager),
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final FarmRole role;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final console = context.console;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;

    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(ConsoleMetrics.radiusSmallButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ConsoleMetrics.radiusSmallButton),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              ConsoleMetrics.radiusSmallButton,
            ),
            border: Border.all(
              color: selected ? Colors.transparent : console.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                role.label,
                style: AppTypography.bodyDense.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: AppTypography.meta.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                      : console.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleMenu extends StatelessWidget {
  const _RoleMenu({required this.member, required this.onChanged});

  final FarmMember member;
  final ValueChanged<FarmRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<FarmRole>(
      tooltip: 'Change role',
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => const [
        PopupMenuItem(value: FarmRole.manager, child: Text('Manager')),
        PopupMenuItem(value: FarmRole.worker, child: Text('Worker')),
      ],
      child: RoleTag(
        member.role,
        trailing: const Icon(Icons.expand_more),
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.onRemove, required this.onNominate});

  final VoidCallback? onRemove;
  final VoidCallback? onNominate;

  @override
  Widget build(BuildContext context) {
    if (onRemove == null && onNominate == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<VoidCallback>(
        tooltip: 'More',
        icon: const Icon(Icons.more_vert, size: 18),
        position: PopupMenuPosition.under,
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          if (onNominate != null)
            PopupMenuItem(
              value: onNominate,
              child: const Text('Nominate as successor'),
            ),
          if (onRemove != null)
            PopupMenuItem(
              value: onRemove,
              child: Text(
                'Remove from farm',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _OwnershipBar extends StatelessWidget {
  const _OwnershipBar({
    required this.ownerName,
    required this.transferPending,
    required this.onNominate,
    required this.onCancel,
  });

  final String ownerName;
  final bool transferPending;
  final VoidCallback onNominate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return ConsoleCard(
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 22, color: console.onSurface2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ownership · $ownerName',
                  style: AppTypography.bodyDense.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transferPending
                      ? 'A transfer is waiting for the other person to '
                            'accept. Nothing has changed yet.'
                      : 'Nominate a manager to take over; they must accept '
                            'before anything changes.',
                  style: AppTypography.meta.copyWith(
                    color: console.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (transferPending)
            ConsoleButton.outlined(
              label: 'Cancel transfer',
              icon: Icons.close,
              onPressed: onCancel,
            )
          else
            ConsoleButton.outlined(
              label: 'Nominate successor',
              icon: Icons.swap_horiz,
              onPressed: onNominate,
            ),
        ],
      ),
    );
  }
}

/// The one-line legend under the table: each role tag beside what it can do.
class _RoleLegend extends StatelessWidget {
  const _RoleLegend();

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        for (final role in FarmRole.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleTag(role),
              const SizedBox(width: 8),
              Text(
                role.permissionSummary.toLowerCase(),
                style: AppTypography.meta.copyWith(color: console.muted),
              ),
            ],
          ),
      ],
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  FarmRole _role = FarmRole.worker;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite a member'),
      titleTextStyle: AppTypography.cardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: AppTypography.bodyDense,
              decoration: const InputDecoration(hintText: 'name@gmail.com'),
            ),
            const SizedBox(height: 12),
            _RoleSegment(
              value: _role,
              onChanged: (role) => setState(() => _role = role),
            ),
          ],
        ),
      ),
      actions: [
        ConsoleButton.outlined(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        ConsoleButton.filled(
          label: 'Send invitation',
          onPressed: () {
            final email = _email.text.trim();
            if (email.isEmpty) return;
            Navigator.pop(context, (email: email, role: _role));
          },
        ),
      ],
    );
  }
}
