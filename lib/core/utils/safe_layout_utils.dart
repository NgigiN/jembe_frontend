import 'package:flutter/material.dart';

extension SafeLayoutContext on BuildContext {
  double get systemBottomInset => MediaQuery.paddingOf(this).bottom;

  EdgeInsets scrollListPadding({bool forFab = false}) {
    const side = 16.0;
    var bottom = side;
    if (forFab) {
      bottom += kFloatingActionButtonMargin + 56.0;
    }
    bottom += systemBottomInset;
    return EdgeInsets.fromLTRB(side, side, side, bottom);
  }
}