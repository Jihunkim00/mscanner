// nutrition_chart.dart (수정 후)
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NutritionChart extends StatelessWidget {
  final double? calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionChart({
    Key? key,
    this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget chartWidget;

    // 단백질, 탄수화물, 지방 데이터가 있을 경우
    final total = protein + carbs + fat;
    if (total > 0) {
      chartWidget = PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: carbs,
              color: Colors.orange,
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: protein,
              color: Colors.green,
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: fat,
              color: Colors.blue,
              radius: 20,
              showTitle: false,
            ),
          ],
          centerSpaceRadius: 10,
          sectionsSpace: 0,
          borderData: FlBorderData(show: false),
        ),
      );
    }
    // kcal 값만 있을 경우 (목표 칼로리 2000 기준)
    else if (calories != null) {
      double target = 2000;
      double percent = (calories! / target).clamp(0, 1);
      chartWidget = PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: percent,
              color: Colors.orange,
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: 1 - percent,
              color: Colors.grey[300],
              radius: 20,
              showTitle: false,
            ),
          ],
          centerSpaceRadius: 10,
          sectionsSpace: 0,
          borderData: FlBorderData(show: false),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    // kcal 값이 있을 경우 도넛 차트 위에 숫자 표시 (중앙 오버레이)
    if (calories != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          chartWidget,
          Text(
            "${calories!.toInt()} kcal",
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      );
    } else {
      return chartWidget;
    }
  }
}
