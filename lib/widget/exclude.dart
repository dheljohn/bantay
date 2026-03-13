// ──────────────────────────────────────────────────────────────
//  lib/widgets/toggle_popup.dart
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

/// A very simple popup that displays an image and a couple of text lines.
/// No internal state – it’s just a static dialog.
class SimplePopup extends StatelessWidget {
  const SimplePopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side – the actual title text
          const Text(
            'Credits',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          // Right side – the close “X” button
          IconButton(
            // Use a material “close” icon (or any icon you prefer)
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            // Reduce the hit‑area padding a little so it looks tight
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            // Close the dialog when tapped
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),

      content: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Image ────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              child: Image.asset('assets/images/lab.jpg', fit: BoxFit.contain),
            ),

            // ── Optional divider (kept for visual separation) ──
            const Divider(height: 32, thickness: 2, indent: 16, endIndent: 16),

            // ── Text lines ─────────────────────────────────────
            const Text('Made with LOVE by: EJ Tubal'),
            const Text('For: Lablab ꨄ︎'),
          ],
        ),
      ),
    );
  }
}

/// Helper that shows the popup. Call it from any widget’s `onPressed`,
/// passing the current `BuildContext`.
Future<void> showSimplePopup(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const SimplePopup(),
  );
}
