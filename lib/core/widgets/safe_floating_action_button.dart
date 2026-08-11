import 'package:flutter/material.dart';

class SafeFloatingActionButton extends StatelessWidget {
  const SafeFloatingActionButton({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16, right: 16),
      child: child,
    );
  }
}