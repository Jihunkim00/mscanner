import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomLinkLauncher extends StatelessWidget {
  final String url;
  final String title;
  final String? subtitle;
  final String? iconPath;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final bool centerAlign; // ✅ 추가

  const CustomLinkLauncher({
    Key? key,
    required this.url,
    required this.title,
    this.subtitle,
    this.iconPath,
    this.titleStyle,
    this.subtitleStyle,
    this.centerAlign = false, // ✅ 기본값 false로 왼쪽정렬
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      },
      child: Column(
        crossAxisAlignment: centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (iconPath != null)
            Image.asset(
              iconPath!,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          Text(
            title,
            style: titleStyle ??
                TextStyle(
                  fontSize: 13,
                  fontFamily: 'SFPro',
                  color: Colors.grey,
                ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: subtitleStyle ??
                  TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
            ),
        ],
      ),
    );
  }
}
