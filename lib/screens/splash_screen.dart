import 'package:flutter/material.dart';

import '../core/design_system/new_ui_theme.dart';
import '../core/design_system/tokens.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [NewUiTokens.heroStart, NewUiTokens.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_white.png',
                  width: AppSize.splashLogo,
                  height: AppSize.splashLogo,
                  semanticLabel: 'Urban Tanker logo',
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'URBAN TANKER',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: NewUiTokens.onHero,
                        letterSpacing: 1.4,
                      ),
                ),
                const SizedBox(height: AppSpace.xxl),
                const SizedBox.square(
                  dimension: AppSize.progressIndicator,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NewUiTokens.onHero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
