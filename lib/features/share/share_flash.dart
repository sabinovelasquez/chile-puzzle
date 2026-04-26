import 'dart:async';

import 'package:flutter/material.dart';

/// Full-screen white scrim used to mask the crop → preview route handoff
/// in the share flow. Behaves like a polaroid camera flash:
///
///   * [cover] inserts an overlay above the navigator and fades it in
///     (120ms easeIn). The returned future resolves once the overlay is
///     fully opaque — at that point the caller can pop / push routes
///     invisibly.
///   * [uncover] starts the fade-out (280ms easeOut). The returned future
///     resolves once the overlay has been removed.
///
/// Lives on the root overlay so it survives `Navigator.pop` / `push`.
class ShareFlash {
  ShareFlash._();

  static OverlayEntry? _entry;
  static GlobalKey<_FlashScrimState>? _key;
  static Timer? _safety;

  static bool get isActive => _entry != null;

  static Future<void> cover(BuildContext context) async {
    if (_entry != null) {
      // A flash is already in flight — wait for it to finish so we don't
      // stack overlays. Then re-cover.
      await uncover();
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey<_FlashScrimState>();
    final entry = OverlayEntry(builder: (_) => _FlashScrim(key: key));
    _key = key;
    _entry = entry;
    overlay.insert(entry);
    // 3-second safety: if the caller never invokes uncover (exception in
    // the swap, etc.) we don't want to leave the screen white forever.
    _safety = Timer(const Duration(seconds: 3), () {
      if (_entry == entry) {
        // ignore: discarded_futures
        uncover();
      }
    });
    // One frame so the overlay paints at opacity 0 before we ramp up.
    await WidgetsBinding.instance.endOfFrame;
    final state = key.currentState;
    if (state == null) return;
    await state.fadeIn();
  }

  static Future<void> uncover() async {
    final entry = _entry;
    final key = _key;
    _entry = null;
    _key = null;
    _safety?.cancel();
    _safety = null;
    if (entry == null) return;
    final state = key?.currentState;
    if (state != null) {
      await state.fadeOut();
    }
    entry.remove();
  }
}

class _FlashScrim extends StatefulWidget {
  const _FlashScrim({super.key});

  @override
  State<_FlashScrim> createState() => _FlashScrimState();
}

class _FlashScrimState extends State<_FlashScrim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 280),
  );

  Future<void> fadeIn() => _ctrl.forward();
  Future<void> fadeOut() => _ctrl.reverse();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          return Opacity(
            opacity: t,
            child: const ColoredBox(
              color: Colors.white,
              child: SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}
