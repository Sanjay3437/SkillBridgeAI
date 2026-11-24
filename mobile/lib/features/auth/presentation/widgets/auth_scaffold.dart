import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -140,
            right: -110,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.indigo.withValues(alpha: 0.14),
                    AppColors.indigo.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandMark(size: 40),
                      const SizedBox(height: 40),
                      Text(title, style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 12),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: child,
                        ),
                      ),
                      if (footer != null) ...[
                        const SizedBox(height: 18),
                        Center(child: footer!),
                      ],
                      const SizedBox(height: 26),
                      Text(
                        AppConfig.disclaimer,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.missingSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.missing.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.missing),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.missing),
            ),
          ),
        ],
      ),
    );
  }
}
