import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'HTML stylesheet class, ID, descendant, and compound selectors match',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Html(
              data: '''
                <style>
                  .class-target { font-size: 20px; }
                  #id-target { font-size: 21px; }
                  .menu .descendant-target { font-size: 22px; }
                  section.menu#menu article.card > p.dish.featured {
                    font-size: 23px;
                  }
                </style>
                <section id="menu" class="menu">
                  <div class="class-target">Class selector</div>
                  <div id="id-target">ID selector</div>
                  <div class="wrapper">
                    <p class="descendant-target">Descendant selector</p>
                  </div>
                  <article class="card">
                    <p class="dish featured">Compound selector</p>
                  </article>
                </section>
              ''',
            ),
          ),
        ),
      );

      _expectRenderedFontSize(tester, 'Class selector', 20);
      _expectRenderedFontSize(tester, 'ID selector', 21);
      _expectRenderedFontSize(tester, 'Descendant selector', 22);
      _expectRenderedFontSize(tester, 'Compound selector', 23);
    },
  );
}

void _expectRenderedFontSize(
  WidgetTester tester,
  String text,
  double expectedFontSize,
) {
  final textFinder = find.text(text, findRichText: true);
  expect(textFinder, findsOneWidget);

  final cssBoxFinder = find.ancestor(
    of: textFinder,
    matching: find.byType(CssBoxWidget),
  );
  expect(cssBoxFinder, findsWidgets);
  final cssBox = tester.widget<CssBoxWidget>(cssBoxFinder.first);
  expect(cssBox.style.fontSize?.value, expectedFontSize, reason: text);
}
