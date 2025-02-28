import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DictationDisplay extends StatelessWidget {
  final String text;
  final bool showCopyButton;

  const DictationDisplay({
    super.key,
    required this.text,
    this.showCopyButton = true,
  });

  void _copyText(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // Take full width
      constraints: const BoxConstraints(
        minHeight: 200, // Minimum height
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCopyButton)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () => _copyText(context),
                tooltip: 'Copy text',
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
              top: showCopyButton ? 0 : 16.0,
            ),
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
