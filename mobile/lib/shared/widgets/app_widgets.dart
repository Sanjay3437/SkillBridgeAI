import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';

/// Renders an [AsyncValue] with consistent loading and error states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () =>
          loading ?? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (error, _) => ErrorView(message: error.toString(), onRetry: onRetry),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.missingSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.cloud_off_rounded, color: AppColors.missing),
            ),
            const SizedBox(height: 16),
            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: AppColors.indigo, size: 30),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label});

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (color, soft, text) = switch (status) {
      'completed' => (AppColors.matched, AppColors.matchedSoft, 'Completed'),
      'queued' || 'processing' => (AppColors.related, AppColors.relatedSoft, 'Processing'),
      'failed' => (AppColors.missing, AppColors.missingSoft, 'Failed'),
      'in_progress' => (AppColors.info, AppColors.infoSoft, 'In progress'),
      'related' => (AppColors.related, AppColors.relatedSoft, 'Related'),
      'matched' => (AppColors.matched, AppColors.matchedSoft, 'Matched'),
      'not_evidenced' => (AppColors.missing, AppColors.missingSoft, 'Gap'),
      _ => (AppColors.muted, AppColors.field, 'Pending'),
    };
    final isBusy = status == 'queued' || status == 'processing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label ?? text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class PriorityPill extends StatelessWidget {
  const PriorityPill({super.key, required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (color, soft) = switch (priority) {
      'high' => (AppColors.missing, AppColors.missingSoft),
      'medium' => (AppColors.related, AppColors.relatedSoft),
      _ => (AppColors.info, AppColors.infoSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '${priority[0].toUpperCase()}${priority.substring(1)} priority',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class CoverageRing extends StatelessWidget {
  const CoverageRing({
    super.key,
    required this.percentage,
    this.size = 132,
    this.label,
    this.trackColor = AppColors.border,
    this.progressColors = const [AppColors.indigo, Color(0xFF7C6CF6), AppColors.indigo],
    this.textColor = AppColors.ink,
    this.labelColor = AppColors.muted,
  });

  final double? percentage;
  final double size;
  final String? label;
  final Color trackColor;
  final List<Color> progressColors;
  final Color textColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final value = ((percentage ?? 0) / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value,
          trackColor: trackColor,
          progressColors: progressColors,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                percentage == null ? '—' : '${percentage!.round()}%',
                style: TextStyle(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: textColor,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    letterSpacing: 0.3,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.trackColor,
    required this.progressColors,
  });

  final double value;
  final Color trackColor;
  final List<Color> progressColors;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (value <= 0) return;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: progressColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * value,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColors != progressColors;
}

/// Soft informational callout used for AI disclaimers.
class InfoCallout extends StatelessWidget {
  const InfoCallout({super.key, required this.message, this.icon = Icons.info_outline_rounded});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.indigo, Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(Icons.alt_route_rounded, color: Colors.white, size: size * 0.55),
        ),
        if (showName) ...[
          const SizedBox(width: 10),
          Text(
            'SkillBridge',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
          ),
        ],
      ],
    );
  }
}
