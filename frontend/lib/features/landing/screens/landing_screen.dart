import 'package:flutter/material.dart';
import 'package:scanserve/features/landing/widgets/features_section.dart';
import 'package:scanserve/features/landing/widgets/hero_section.dart';
import 'package:scanserve/features/landing/widgets/how_it_works_section.dart';
import 'package:scanserve/features/landing/widgets/landing_footer.dart';
import 'package:scanserve/features/landing/widgets/landing_header.dart';

/// Marketing landing page, served at "/".
/// This screen is presentation-only - no auth, no data fetching.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            LandingHeader(),
            HeroSection(),
            HowItWorksSection(),
            FeaturesSection(),
            LandingFooter(),
          ],
        ),
      ),
    );
  }
}
