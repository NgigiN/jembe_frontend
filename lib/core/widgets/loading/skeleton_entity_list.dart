import 'package:farm_tracker/core/widgets/crud/entity_card.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A loading placeholder for pages that show a list of [EntityCard]s.
///
/// Always skeletonized - only render this from a `BlocBuilder`'s Loading
/// branch. Once data loads, the page should switch to its normal branch
/// with real [EntityCard]s, not toggle this widget's skeleton state.
class SkeletonEntityList extends StatelessWidget {
  const SkeletonEntityList({
    super.key,
    this.icon = Icons.circle,
    this.itemCount = 6,
  });

  final IconData icon;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) => EntityCard(
          icon: icon,
          iconColor: Colors.grey,
          title: 'Loading title placeholder',
          subtitle: 'Loading subtitle placeholder text',
          onTap: () {},
        ),
      ),
    );
  }
}
