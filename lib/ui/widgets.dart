import 'dart:math';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/state.dart';

class PatternPainter extends CustomPainter {
  final Color color;
  PatternPainter(this.color);
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 44.0, r = 16.0;
    for (double y = 0; y < s.height + step; y += step) {
      for (double x = 0; x < s.width + step; x += step) {
        for (var k = 0; k < 2; k++) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = (pi / 4) * (1 + 2 * i) + k * pi / 4;
            final pt = Offset(x + r * cos(a), y + r * sin(a));
            if (i == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          path.close();
          c.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PatternPainter old) => old.color != color;
}

String psLabel(PS s) => t(s.name);

Color psColor(PS s) {
  switch (s) {
    case PS.prayed:
      return const Color(0xFF2E9E62);
    case PS.qada:
      return const Color(0xFF3B82C4);
    case PS.active:
      return const Color(0xFFD08A12);
    case PS.expired:
    case PS.missed:
      return const Color(0xFFC0392B);
    case PS.upcoming:
      return const Color(0xFF7A8A80);
  }
}

Future<void> statusSheet(BuildContext ctx, String date, int p) {
  Widget item(IconData icon, String key, int st) => ListTile(
        leading: Icon(icon),
        title: Text(t(key)),
        onTap: () {
          Navigator.pop(ctx);
          AppState.i.setStatus(date, p, st);
        },
      );
  return showModalBottomSheet<void>(
    context: ctx,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text('${t(prayerKeys[p])}  •  $date', style: const TextStyle(fontWeight: FontWeight.bold))),
        item(Icons.check_circle, 'markPrayed', stPrayed),
        item(Icons.history_toggle_off, 'qadaDone', stQada),
        item(Icons.cancel, 'recordMissed', stMissed),
        item(Icons.restart_alt, 'clear', stNone),
      ]),
    ),
  );
}

Future<String?> askText(BuildContext c, String title, String init, {bool multiline = false}) {
  final ctl = TextEditingController(text: init);
  return showDialog<String>(
    context: c,
    builder: (dc) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        maxLines: multiline ? 8 : 1,
        keyboardType: multiline ? TextInputType.multiline : const TextInputType.numberWithOptions(decimal: true, signed: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: Text(t('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(dc, ctl.text.trim()), child: Text(t('save'))),
      ],
    ),
  );
}

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
