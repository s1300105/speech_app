import 'package:flutter/material.dart';

class MenuButton extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback onPressed;

  const MenuButton({
    required this.imagePath,
    required this.title,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Image.asset(imagePath, width: 180, height: 100),
        ),
        const SizedBox(height: 5), // 画像とタイトルの間隔
        Text(
          title,
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        const SizedBox(height: 20), // 各ボタン間のスペース
      ],
    );
  }
}