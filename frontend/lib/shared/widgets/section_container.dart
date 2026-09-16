import 'package:flutter/material.dart';
import 'package:scanserve/core/utils/responsive.dart';

/// Centers content, caps its width on large screens, and applies
/// consistent horizontal/vertical padding. Used for every landing
/// page section so spacing never has to be hand-tuned per section.
class SectionContainer extends StatelessWidget {
  const SectionContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.verticalPadding = 64,
  });

  final Widget child;
  final Color? backgroundColor;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.pagePadding(context),
        vertical: verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.maxContentWidth(context),
          ),
          child: child,
        ),
      ),
    );
  }
}
