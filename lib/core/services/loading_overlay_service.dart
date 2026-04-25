import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global loading overlay — a single ValueNotifier the root widget watches
/// via [LoadingOverlayHost]. The overlay sits above all routes, so it can
/// bridge screen transitions (e.g. ad-dismiss → puzzle pop → map reload)
/// without flicker.
class LoadingOverlayService {
  LoadingOverlayService._();

  static final ValueNotifier<bool> _visible = ValueNotifier(false);

  static ValueListenable<bool> get listenable => _visible;

  static void show() {
    _visible.value = true;
  }

  static void hide() {
    _visible.value = false;
  }
}

/// Wraps a child with the full-screen loader that appears whenever
/// [LoadingOverlayService.show] has been called. Place above the Navigator
/// (via MaterialApp.builder) so it survives route pushes/pops.
class LoadingOverlayHost extends StatelessWidget {
  final Widget child;
  const LoadingOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: LoadingOverlayService.listenable,
          builder: (_, visible, __) {
            if (!visible) return const SizedBox.shrink();
            return const Positioned.fill(child: _LoaderBody());
          },
        ),
      ],
    );
  }
}

class _LoaderBody extends StatelessWidget {
  const _LoaderBody();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: const Center(
        child: ClipOval(
          child: SizedBox(
            width: 96,
            height: 96,
            child: Image(
              image: AssetImage('assets/loader.gif'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
