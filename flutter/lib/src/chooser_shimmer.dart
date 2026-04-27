import 'package:flutter/material.dart';

class ChooserShimmer extends StatefulWidget {
  const ChooserShimmer({super.key});

  @override
  State<ChooserShimmer> createState() => _ChooserShimmerState();
}

class _ChooserShimmerState extends State<ChooserShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading payment options',
    child: Container(
      color: _kPrimary,
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pos = -0.5 + 2 * _controller.value;
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [_kBase, _kHighlight, _kBase],
                stops: [pos - 0.5, pos, pos + 0.5],
                tileMode: TileMode.clamp,
              ).createShader(bounds),
              blendMode: BlendMode.srcATop,
              child: child,
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SkeletonBox(width: 180, height: 28, radius: 6),
                      _SkeletonBox(width: 24, height: 24, shape: BoxShape.circle),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                _SkeletonBox(width: 220, height: 18, radius: 6),
                SizedBox(height: 32),
                _SkeletonBox(width: 200, height: 21, radius: 6),
                SizedBox(height: 12),
                _SkeletonTile(),
                SizedBox(height: 16),
                _SkeletonTile(),
                SizedBox(height: 32),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SkeletonBox(width: 60, height: 14, radius: 4),
                      SizedBox(width: 8),
                      _SkeletonBox(width: 50, height: 14, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final BoxShape shape;

  const _SkeletonBox({required this.width, required this.height, this.radius = 0, this.shape = BoxShape.rectangle});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: _kBase,
      shape: shape,
      borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null,
    ),
  );
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _kTile, borderRadius: BorderRadius.circular(16)),
    child: const Row(
      children: [
        _SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SkeletonBox(width: 110, height: 18, radius: 4),
              SizedBox(height: 4),
              _SkeletonBox(width: double.infinity, height: 14, radius: 4),
            ],
          ),
        ),
        SizedBox(width: 16),
        _SkeletonBox(width: 24, height: 24, radius: 4),
      ],
    ),
  );
}

const Color _kPrimary = Color(0xFFEDF2ED);
const Color _kTile = Color(0xFFFFFFFF);
const Color _kBase = Color(0xFFD1D9D1);
const Color _kHighlight = Color(0xFFEDF2ED);
