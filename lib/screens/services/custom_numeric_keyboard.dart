import 'package:flutter/material.dart';

class CustomNumericKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onDone; // Callback untuk tombol "Done"

  const CustomNumericKeyboard({
    super.key,
    required this.controller,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2 / 1.3, // Sesuaikan rasio agar nyaman disentuh
        children: [
          ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((key) {
            return _buildButton(key, () => _onInput(key));
          }),
          _buildButton(',', () => _onInput(',')), // Tombol TITIK
          _buildButton('0', () => _onInput('0')),
          _buildButton(
            // Tombol Hapus (Backspace)
            const Icon(Icons.backspace_outlined, color: Colors.black54),
            _onBackspace,
            isIcon: true,
          ),
        ],
      ),
    );
  }

  void _onInput(String text) {
    // Mencegah ada lebih dari satu titik
    if (text == ',' && controller.text.contains(',')) return;
    controller.text += text;
  }

  void _onBackspace() {
    if (controller.text.isNotEmpty) {
      controller.text = controller.text.substring(0, controller.text.length - 1);
    }
  }

  Widget _buildButton(dynamic child, VoidCallback onPressed, {bool isIcon = false}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Center(
          child: isIcon
              ? child
              : Text(
            child.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}