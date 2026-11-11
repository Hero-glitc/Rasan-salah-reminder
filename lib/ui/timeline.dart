import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/state.dart';

String _fmt(int m) => '${two(m ~/ 60)}:${two(m % 60)}';
int _toMin(String s) {
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Bottom sheet where the start and end of one prayer are set by dragging markers on a 24-hour timeline.
Future<void> editTimeline(BuildContext ctx, int i) {
  final c = AppState.i.cfg;
  var s = _toMin(c.ms(i));
  var e = _toMin(c.me(i));
  return showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    builder: (sc) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(sc).viewInsets.bottom),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t(prayerKeys[i]), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(t('dragHint'), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(sc).colorScheme.outline)),
          const SizedBox(height: 8),
          TimelineRange(
            start: s,
            end: e,
            onChanged: (a, b) {
              s = a;
              e = b;
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sc), child: Text(t('cancel')))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  if (s == e) e = (e + 5) % 1440;
                  Navigator.pop(sc);
                  AppState.i.save({'ms$i': _fmt(s), 'me$i': _fmt(e)});
                },
                child: Text(t('save')),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

class TimelineRange extends StatefulWidget {
  final int start, end; // minutes after midnight
  final void Function(int start, int end) onChanged;
  const TimelineRange({super.key, required this.start, required this.end, required this.onChanged});
  @override
  State<TimelineRange> createState() => _TimelineRangeState();
}

class _TimelineRangeState extends State<TimelineRange> {
  late int s, e;
  int active = -1;

  @override
  void initState() {
    super.initState();
    s = widget.start;
    e = widget.end;
  }

  void _pick(double dx, double w) {
    final ds = (dx - s / 1440 * w).abs(), de = (dx - e / 1440 * w).abs();
    active = ds <= de ? 0 : 1;
  }

  void _move(double dx, double w) {
    var m = ((dx / w).clamp(0.0, 1.0) * 1440 / 5).round() * 5;
    if (m >= 1440) m = 0;
    setState(() {
      if (active == 0) {
        s = m;
      } else {
        e = m;
      }
    });
    widget.onChanged(s, e);
  }

  void _nudge(int which, int delta) {
    setState(() {
      if (which == 0) {
        s = (s + delta + 1440) % 1440;
      } else {
        e = (e + delta + 1440) % 1440;
      }
    });
    widget.onChanged(s, e);
  }

  Widget _fine(String label, int which, int value, Color color) => Expanded(
        child: Column(children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () => _nudge(which, -1), icon: const Icon(Icons.remove_circle_outline)),
            Text(_fmt(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            IconButton(onPressed: () => _nudge(which, 1), icon: const Icon(Icons.add_circle_outline)),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: LayoutBuilder(builder: (ctx, bc) {
          final w = bc.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              _pick(d.localPosition.dx, w);
              _move(d.localPosition.dx, w);
            },
            onHorizontalDragStart: (d) => _pick(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
            child: SizedBox(
              height: 150,
              width: w,
              child: CustomPaint(
                painter: _TimelinePainter(
                  s: s,
                  e: e,
                  active: active,
                  cStart: cs.primary,
                  cEnd: cs.tertiary,
                  track: cs.surfaceContainerHighest,
                  text: cs.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
      Row(children: [
        _fine(t('startLbl'), 0, s, cs.primary),
        _fine(t('endLbl'), 1, e, cs.tertiary),
      ]),
    ]);
  }
}

class _TimelinePainter extends CustomPainter {
  final int s, e, active;
  final Color cStart, cEnd, track, text;
  _TimelinePainter({required this.s, required this.e, required this.active, required this.cStart, required this.cEnd, required this.track, required this.text});

  void _txt(Canvas c, String str, Offset center, Color col, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: str, style: TextStyle(color: col, fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _marker(Canvas c, double w, double trackY, double x, int minutes, Color color, double bubbleTop, bool isActive) {
    final label = _fmt(minutes);
    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final bw = tp.width + 18;
    const bh = 26.0;
    final bx = math.min(math.max(x, bw / 2), w - bw / 2);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2;
    c.drawLine(Offset(x, bubbleTop + bh), Offset(x, trackY - 13), line);
    final fill = Paint()..color = color;
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(bx, bubbleTop + bh / 2), width: bw, height: bh), const Radius.circular(13)),
      fill,
    );
    tp.paint(c, Offset(bx - tp.width / 2, bubbleTop + (bh - tp.height) / 2));
    c.drawCircle(Offset(x, trackY), isActive ? 15 : 13, fill);
    c.drawCircle(Offset(x, trackY), 5, Paint()..color = Colors.white);
  }

  @override
  void paint(Canvas c, Size size) {
    final w = size.width;
    const trackY = 100.0;
    double x(int m) => m / 1440 * w;
    final base = Paint()
      ..color = track
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(0, trackY), Offset(w, trackY), base);
    final range = Paint()
      ..color = cStart.withOpacity(0.55)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    if (e > s) {
      c.drawLine(Offset(x(s), trackY), Offset(x(e), trackY), range);
    } else {
      c.drawLine(Offset(x(s), trackY), Offset(w, trackY), range);
      c.drawLine(Offset(0, trackY), Offset(x(e), trackY), range);
    }
    final tick = Paint()
      ..color = text.withOpacity(0.4)
      ..strokeWidth = 1;
    for (var h = 0; h <= 24; h++) {
      final xx = h / 24 * w;
      c.drawLine(Offset(xx, trackY + 14), Offset(xx, trackY + (h % 3 == 0 ? 24 : 19)), tick);
      if (h % 3 == 0) _txt(c, two(h), Offset(xx, trackY + 34), text.withOpacity(0.7), 11);
    }
    _marker(c, w, trackY, x(s), s, cStart, trackY - 46, active == 0);
    _marker(c, w, trackY, x(e), e, cEnd, trackY - 82, active == 1);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}
