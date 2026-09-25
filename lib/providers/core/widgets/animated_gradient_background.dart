import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';

/// A layered, "premium service app" style animated background: soft
/// floating color blobs plus a few faint, slowly-drifting service icons
/// (wrench, broom, spark) behind [child] — evokes the kind of polished
/// backdrop apps like Urban Company/TaskRabbit use, rather than a flat
/// gradient sweep.
///
/// Same API as before (colors, duration, child), so screens already
/// using AnimatedGradientBackground don't need any changes.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.duration = const Duration(seconds: 18),
    this.showServiceIcons = true,
  });

  final Widget child;
  final List<Color>? colors;
  final Duration duration;

  /// Set false on very content-dense screens if the icon texture feels
  /// like too much — the blobs alone still read as "alive."
  final bool showServiceIcons;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _serviceIcons = [
    Icons.plumbing,
    Icons.cleaning_services,
    Icons.electrical_services,
    Icons.handyman,
    Icons.format_paint_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = (widget.colors != null && widget.colors!.isNotEmpty)
        ? widget.colors!.first
        : AppColors.primary;
    final secondary =
        (widget.colors != null && widget.colors!.length > 1) ? widget.colors![1] : primary;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base — keeps text/cards readable regardless of theme.
          Container(color: Theme.of(context).scaffoldBackgroundColor),

          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value * 2 * math.pi;
              return Stack(
                children: [
                  _blob(
                    color: primary,
                    size: 260,
                    top: 40 + math.sin(t) * 30,
                    left: -60 + math.cos(t * 0.8) * 20,
                    opacity: 0.16,
                  ),
                  _blob(
                    color: secondary,
                    size: 220,
                    top: 220 + math.cos(t * 0.9) * 25,
                    right: -50 + math.sin(t * 0.7) * 18,
                    opacity: 0.14,
                  ),
                  _blob(
                    color: primary,
                    size: 300,
                    bottom: -80 + math.sin(t * 0.6) * 20,
                    left: 40 + math.cos(t) * 25,
                    opacity: 0.10,
                  ),
                  if (widget.showServiceIcons)
                    ..._serviceIcons.asMap().entries.map((entry) {
                      final i = entry.key;
                      final icon = entry.value;
                      final phase = t + (i * math.pi / 2.5);
                      final screenSize = MediaQuery.of(context).size;
                      return Positioned(
                        left: (screenSize.width * (0.12 + i * 0.2)) +
                            math.sin(phase) * 14,
                        top: (screenSize.height * (0.1 + (i % 3) * 0.28)) +
                            math.cos(phase * 0.8) * 12,
                        child: Transform.rotate(
                          angle: math.sin(phase * 0.5) * 0.15,
                          child: Icon(
                            icon,
                            size: 34,
                            color: primary.withOpacity(0.06),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),

          widget.child,
        ],
      ),
    );
  }

  Widget _blob({
    required Color color,
    required double size,
    required double opacity,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}
