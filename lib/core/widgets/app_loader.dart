import 'package:flutter/material.dart';

/// In-place loader using the same girl-cat-walking gif as the global overlay.
/// Use anywhere you'd otherwise drop a [CircularProgressIndicator] so the
/// loading affordance stays consistent across the app.
class AppLoader extends StatelessWidget {
  final double size;
  const AppLoader({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: const Image(
          image: AssetImage('assets/loader.gif'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
