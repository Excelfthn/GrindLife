import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg = Color(0xFF15131D);
  static const sheet = Color(0xFF1C1A27);
  static const surface = Color(0xFF211E2C);
  static const surface2 = Color(0xFF2B2740);
  static const menu = Color(0xFF2B2838);
  static const line = Color(0xFF34304A);
  static const line2 = Color(0xFF4A4563);
  static const grid = Color(0xFF2A2738);
  static const text = Color(0xFFF4EFE4);
  static const muted = Color(0xFFABA5BC);
  static const faint = Color(0xFF8F89A3);
  static const gold = Color(0xFFF2B544);
  static const goldDark = Color(0xFFB8812A);
  static const goldSoft = Color(0xFF3A3020);
  static const teal = Color(0xFF5ED0C2);
  static const purple = Color(0xFF9C8CFF);
  static const purpleLight = Color(0xFFB9ADFF);
  static const coral = Color(0xFFFF9B73);
}

const attrCodes = ['INT', 'STR', 'CHA', 'WIS'];

const attrColors = {
  'INT': C.purple,
  'STR': C.coral,
  'CHA': C.teal,
  'WIS': C.gold,
};

const attrNames = {
  'INT': 'Learning',
  'STR': 'Body',
  'CHA': 'Social',
  'WIS': 'Mind',
};

TextStyle pixel(double size, {Color color = C.text, FontWeight weight = FontWeight.w700}) {
  try {
    return GoogleFonts.getFont('Pixelify Sans', fontSize: size, color: color, fontWeight: weight);
  } catch (_) {
    // Fallback if the font is unavailable in this google_fonts version.
    return TextStyle(fontSize: size, color: color, fontWeight: weight, fontFamily: 'monospace');
  }
}

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.gold,
      onPrimary: C.bg,
      secondary: C.teal,
      surface: C.sheet,
      onSurface: C.text,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text),
    splashColor: const Color(0x14F4EFE4),
    highlightColor: const Color(0x0AF4EFE4),
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Color(0xFF3A3650)),
      thickness: WidgetStatePropertyAll(4),
      radius: Radius.circular(3),
    ),
  );
}

/// Rounded box decoration used across the app.
BoxDecoration box({Color color = C.surface, Color border = C.line, double radius = 14, double borderWidth = 1}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: borderWidth),
  );
}

/// Gold primary button with the chunky RPG shadow.
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onTap, this.icon, this.height = 50});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: C.goldDark, offset: Offset(0, 5))],
      ),
      child: Material(
        color: C.gold,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, color: C.bg, size: 20), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(color: C.bg, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12, color: C.muted)),
    );
  }
}

InputDecoration fieldDecoration({String? hint}) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: C.faint),
    isDense: true,
    filled: true,
    fillColor: C.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    enabledBorder: b(C.line2),
    focusedBorder: b(C.gold),
    border: b(C.line2),
  );
}

/// Rounded floating menu, used instead of the system dropdown.
Future<T?> showRoundMenu<T>(BuildContext context, List<String> labels, List<T> values, T current) {
  final renderBox = context.findRenderObject() as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final topLeft = renderBox.localToGlobal(Offset(0, renderBox.size.height), ancestor: overlay);
  final rect = RelativeRect.fromLTRB(
    overlay.size.width - 16 - 200,
    topLeft.dy,
    16,
    overlay.size.height - topLeft.dy,
  );
  return showMenu<T>(
    context: context,
    position: rect,
    color: C.menu,
    elevation: 12,
    constraints: const BoxConstraints(minWidth: 190, maxWidth: 220),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: C.line2),
    ),
    items: [
      for (var i = 0; i < labels.length; i++)
        PopupMenuItem<T>(
          value: values[i],
          height: 42,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: values[i] == current ? C.goldSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            width: double.infinity,
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 14,
                color: values[i] == current ? C.gold : C.text,
                fontWeight: values[i] == current ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
    ],
  );
}

Future<void> showComingSoon(BuildContext context, String title, String body) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xB808070C),
    builder: (ctx) => Dialog(
      backgroundColor: C.sheet,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: C.line)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: box(color: C.surface2, border: C.surface2, radius: 16),
              child: const Center(child: PixelArt(sprite: Sprites.mascot, size: 40)),
            ),
            const SizedBox(height: 12),
            Text(title, style: pixel(22), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.5, color: C.muted)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: GoldButton(label: 'Got it', onTap: () => Navigator.pop(ctx), height: 48)),
          ],
        ),
      ),
    ),
  );
}

/// Tiny pixel-art sprites drawn from rectangles on a square grid.
class Sprite {
  const Sprite(this.grid, this.pixels);
  final int grid;
  final List<List<int>> pixels; // [x, y, w, h, color]
}

class Sprites {
  static const avatar = Sprite(12, [
    [3, 1, 6, 2, 0xFF3A2A1E],
    [3, 3, 6, 4, 0xFFF0C9A0],
    [4, 4, 1, 1, 0xFF15131D],
    [7, 4, 1, 1, 0xFF15131D],
    [5, 6, 2, 1, 0xFFC98A6B],
    [2, 7, 8, 5, 0xFF5ED0C2],
    [5, 7, 2, 5, 0xFFF2B544],
    [1, 8, 1, 3, 0xFFF0C9A0],
    [10, 8, 1, 3, 0xFFF0C9A0],
    [2, 7, 1, 1, 0xFF9C8CFF],
    [9, 7, 1, 1, 0xFF9C8CFF],
  ]);
  static const mascot = Sprite(10, [
    [2, 3, 6, 5, 0xFFF2B544],
    [1, 2, 2, 2, 0xFFF2B544],
    [7, 2, 2, 2, 0xFFF2B544],
    [3, 5, 1, 1, 0xFF15131D],
    [6, 5, 1, 1, 0xFF15131D],
    [4, 6, 2, 1, 0xFFC98A6B],
    [2, 8, 2, 1, 0xFFB8812A],
    [6, 8, 2, 1, 0xFFB8812A],
  ]);
  static const boss = Sprite(10, [
    [2, 1, 6, 7, 0xFF9C8CFF],
    [1, 0, 1, 2, 0xFF9C8CFF],
    [8, 0, 1, 2, 0xFF9C8CFF],
    [3, 3, 1, 1, 0xFFFF9B73],
    [6, 3, 1, 1, 0xFFFF9B73],
    [3, 5, 4, 1, 0xFF15131D],
    [2, 8, 2, 2, 0xFF7A6BD9],
    [6, 8, 2, 2, 0xFF7A6BD9],
  ]);
  static const boots = Sprite(12, [
    [2, 3, 4, 5, 0xFFFF9B73],
    [6, 6, 4, 2, 0xFFFF9B73],
    [1, 8, 10, 1, 0xFFF4EFE4],
    [1, 9, 10, 1, 0xFF8F89A3],
    [3, 4, 2, 1, 0xFFF4EFE4],
    [3, 6, 2, 1, 0xFFF4EFE4],
    [2, 2, 4, 1, 0xFFC96A4B],
    [9, 2, 1, 1, 0xFFF2B544],
    [10, 1, 1, 1, 0xFFF2B544],
  ]);
}

class PixelArt extends StatelessWidget {
  const PixelArt({super.key, required this.sprite, required this.size});
  final Sprite sprite;
  final double size;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _PixelPainter(sprite));
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.sprite);
  final Sprite sprite;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / sprite.grid;
    final paint = Paint()..isAntiAlias = false;
    for (final p in sprite.pixels) {
      paint.color = Color(p[4]);
      canvas.drawRect(Rect.fromLTWH(p[0] * unit, p[1] * unit, p[2] * unit, p[3] * unit), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelPainter old) => old.sprite != sprite;
}
