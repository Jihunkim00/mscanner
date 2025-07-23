import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final File image;
  final String resultText;

  ResultCard({required this.image, required this.resultText});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Image.file(image, fit: BoxFit.cover, width: double.infinity),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            resultText,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
