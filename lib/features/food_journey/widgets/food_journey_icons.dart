import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../models/food_journey_summary.dart';
import 'food_journey_style.dart';

enum FoodJourneyIconType {
  passport,
  globe,
  dna,
  noodles,
  rice,
  meat,
  seafood,
  soup,
  vegetables,
  dessert,
  drinks,
  calendar,
  chart;

  static FoodJourneyIconType forCategory(FoodCategory category) =>
      switch (category) {
        FoodCategory.noodles => noodles,
        FoodCategory.rice => rice,
        FoodCategory.meat => meat,
        FoodCategory.seafood => seafood,
        FoodCategory.soup => soup,
        FoodCategory.vegetables => vegetables,
        FoodCategory.dessert => dessert,
        FoodCategory.drinks => drinks,
        FoodCategory.unknown => dna,
      };
}

/// Decorative by default; callers can supply a localized accessibility label.
class FoodJourneyIcon extends StatelessWidget {
  const FoodJourneyIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final FoodJourneyIconType type;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? FoodJourneyStyle.of(context).accent;
    final icon = switch (type) {
      FoodJourneyIconType.passport ||
      FoodJourneyIconType.noodles ||
      FoodJourneyIconType.meat =>
        CustomPaint(
            size: Size.square(size), painter: _JourneyPainter(type, ink)),
      _ => Icon(
          switch (type) {
            FoodJourneyIconType.globe =>
              PhosphorIconsRegular.globeHemisphereWest,
            FoodJourneyIconType.dna => PhosphorIconsRegular.dna,
            FoodJourneyIconType.rice => PhosphorIconsRegular.bowlFood,
            FoodJourneyIconType.seafood => PhosphorIconsRegular.fish,
            FoodJourneyIconType.soup => PhosphorIconsRegular.bowlSteam,
            FoodJourneyIconType.vegetables => PhosphorIconsRegular.carrot,
            FoodJourneyIconType.dessert => PhosphorIconsRegular.cake,
            FoodJourneyIconType.drinks => PhosphorIconsRegular.coffee,
            FoodJourneyIconType.calendar => PhosphorIconsRegular.calendarBlank,
            _ => PhosphorIconsRegular.chartBar,
          },
          size: size,
          color: ink,
        ),
    };
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: icon,
    );
  }
}

/// Missing food/travel glyphs share Phosphor's 24-unit, round, two-unit outline.
class _JourneyPainter extends CustomPainter {
  const _JourneyPainter(this.type, this.color);
  final FoodJourneyIconType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (type) {
      case FoodJourneyIconType.passport:
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(4, 2.5, 16, 19),
                const Radius.circular(2.5)),
            pen);
        canvas.drawLine(const Offset(7, 3), const Offset(7, 21), pen);
        canvas.drawCircle(const Offset(13.5, 10), 4, pen);
        canvas.drawOval(const Rect.fromLTWH(12, 6, 3, 8), pen);
        canvas.drawLine(const Offset(9.5, 10), const Offset(17.5, 10), pen);
        canvas.drawLine(const Offset(11, 18), const Offset(16, 18), pen);
      case FoodJourneyIconType.noodles:
        canvas.drawPath(
            Path()
              ..moveTo(3, 13)
              ..cubicTo(4, 22, 20, 22, 21, 13)
              ..close(),
            pen);
        canvas.drawLine(const Offset(5, 4), const Offset(21, 2), pen);
        canvas.drawLine(const Offset(5, 7), const Offset(21, 5), pen);
        for (final x in [9.0, 13.0, 17.0]) {
          canvas.drawPath(
              Path()
                ..moveTo(x, 6.5)
                ..cubicTo(x - 2, 9, x + 2, 10, x, 13),
              pen);
        }
        canvas.drawLine(const Offset(9, 21), const Offset(15, 21), pen);
      case FoodJourneyIconType.meat:
        canvas.drawPath(
            Path()
              ..moveTo(5, 5)
              ..cubicTo(10, 1, 14, 5, 15, 8)
              ..cubicTo(16, 11, 22, 12, 21, 17)
              ..cubicTo(20, 23, 10, 22, 6, 18)
              ..cubicTo(2, 15, 1, 8, 5, 5)
              ..close(),
            pen);
        canvas.drawOval(const Rect.fromLTWH(6, 7, 5, 4), pen);
        canvas.drawLine(const Offset(10, 15), const Offset(12, 17), pen);
        canvas.drawLine(const Offset(14, 14), const Offset(16, 16), pen);
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_JourneyPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
