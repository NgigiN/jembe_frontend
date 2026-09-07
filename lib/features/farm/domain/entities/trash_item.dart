import 'package:equatable/equatable.dart';

/// One soft-deleted row from `GET /api/v1/trash` (Phase 8 A2), flattened out
/// of the backend's per-entity grouping.
///
/// [entity] is the trash response's snake_case group key (`land`, `plant`,
/// `season`, `activity`, `input`, `harvest`, `animal_type`, `herd`,
/// `animal`, `infrastructure`, `cost_category`, `revenue` — see
/// `trashEntities` in `trash_item_model.dart`). It doubles as the restore
/// call's addressing key: `TrashRemoteDataSourceImpl.restore` maps it to the
/// entity's actual REST path segment (e.g. `land` restores at
/// `POST /api/v1/lands/:id/restore`, not `/api/v1/land/...`).
///
/// [label] is a best-effort display string derived generically from
/// whatever fields the row happens to carry (`name`/`title`/`type`/
/// `date`/quantity+unit/amount, else `#<id>`) — Phase 8 B2 is a pragmatic
/// restore utility, not 12 typed row models, so no entity gets a bespoke
/// shape here. See `trash_item_model.dart`'s label derivation.
class TrashItem extends Equatable {
  const TrashItem({
    required this.entity,
    required this.id,
    required this.label,
    this.deletedAt,
  });

  final String entity;
  final String id;
  final String label;

  /// Null when the row didn't carry a parseable `deleted_at` — the backend
  /// response DTOs (as of Phase 8 A2) don't currently serialize it, so this
  /// is commonly null in practice; still parsed defensively in case a
  /// future response includes it.
  final DateTime? deletedAt;

  @override
  List<Object?> get props => [entity, id, label, deletedAt];
}
