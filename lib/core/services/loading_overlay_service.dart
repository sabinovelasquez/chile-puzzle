import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chile_puzzle/core/widgets/app_loader.dart';

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
///
/// The overlay crossfades on visibility change (≈320ms easeOut), so when
/// hide() fires the underlying screen reveals itself smoothly instead of
/// popping in.
class LoadingOverlayHost extends StatelessWidget {
  final Widget child;
  const LoadingOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: LoadingOverlayService.listenable,
            builder: (_, visible, __) => IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                opacity: visible ? 1.0 : 0.0,
                child: const _LoaderBody(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoaderBody extends StatelessWidget {
  const _LoaderBody();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.white,
      child: Center(child: AppLoader(size: 96)),
    );
  }
}
