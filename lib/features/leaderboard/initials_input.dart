import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:chile_puzzle/core/theme/app_theme.dart';

/// Arcade-style 3-letter initials input dialog.
/// Returns the 3-letter string or null if cancelled.
Future<String?> showInitialsInput(BuildContext context, {String? currentInitials}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _InitialsDialog(currentInitials: currentInitials),
  );
}

class _InitialsDialog extends StatefulWidget {
  final String? currentInitials;
  const _InitialsDialog({this.currentInitials});

  @override
  State<_InitialsDialog> createState() => _InitialsDialogState();
}

class _InitialsDialogState extends State<_InitialsDialog> {
  late List<int> _letters; // 0-25 → A-Z

  @override
  void initState() {
    super.initState();
    if (widget.currentInitials != null && widget.currentInitials!.length == 3) {
      _letters = widget.currentInitials!.codeUnits.map((c) => c - 65).toList();
    } else {
      _letters = [0, 0, 0]; // AAA
    }
  }

  String get _initials => String.fromCharCodes(_letters.map((i) => i + 65));

  @override
  Widget build(BuildContext context) {
    final langCode = Localizations.localeOf(context).languageCode;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsFill.gameController, size: 40, color: AppTheme.accentPurple),
            const SizedBox(height: 12),
            Text(
              langCode == 'es' ? 'Ingresa tus iniciales' : 'Enter your initials',
              style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              langCode == 'es' ? '3 letras, estilo arcade' : '3 letters, arcade style',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // 3 letter slots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => _LetterSlot(
                letter: _letters[i],
                onUp: () => setState(() { _letters[i] = (_letters[i] + 1) % 26; }),
                onDown: () => setState(() { _letters[i] = (_letters[i] - 1 + 26) % 26; }),
              )),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(langCode == 'es' ? 'Cancelar' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _initials),
                    child: Text(langCode == 'es' ? 'Confirmar' : 'Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterSlot extends StatelessWidget {
  final int letter; // 0-25
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _LetterSlot({
    required this.letter,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: onUp,
            child: Container(
              width: 48, height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(PhosphorIconsBold.caretUp, size: 20, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 56, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.seedColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: AppTheme.seedColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Center(
              child: Text(
                String.fromCharCode(letter + 65),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onDown,
            child: Container(
              width: 48, height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(PhosphorIconsBold.caretDown, size: 20, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}
