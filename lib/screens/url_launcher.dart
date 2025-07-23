import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomLinkLauncher extends StatelessWidget {
  final String url;
  final String title;
  final String? subtitle;
  final String? iconPath;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const CustomLinkLauncher({
    Key? key,
    required this.url,
    required this.title,
    this.subtitle,
    this.iconPath,
    this.titleStyle,
    this.subtitleStyle,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
        children: [
          if (iconPath != null)
            Image.asset(
              iconPath!,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            )
          else
            const SizedBox.shrink(), // 아이콘 없으면 빈 박스
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
              children: [
                Text(
                  title,
                  style: titleStyle ??
                      const TextStyle(
                        fontSize: 13,
                        fontFamily: 'SFPro',
                        color: Colors.grey,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: subtitleStyle ??
                        const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
