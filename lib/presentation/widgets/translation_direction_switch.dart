import 'package:flutter/material.dart';

import '../../domain/models/translation_direction.dart';

/// 翻訳方向を切り替えるセグメントボタンスイッチ
class TranslationDirectionSwitch extends StatelessWidget {
  const TranslationDirectionSwitch({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TranslationDirection selected;
  final ValueChanged<TranslationDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TranslationDirection>(
        segments: const [
          ButtonSegment(
            value: TranslationDirection.enToJa,
            label: Text('英語 → 日本語'),
            icon: Icon(Icons.language, size: 16),
          ),
          ButtonSegment(
            value: TranslationDirection.jaToEn,
            label: Text('日本語 → 英語'),
            icon: Icon(Icons.translate, size: 16),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (newSelection) {
          if (newSelection.isNotEmpty) {
            onChanged(newSelection.first);
          }
        },
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
