import 'package:flutter/material.dart';

import '../services/mpin_service.dart';

/// Digit dots and a number keypad for entering an MPIN.
class PinPad extends StatelessWidget {
  const PinPad({
    required this.entered,
    required this.onDigit,
    required this.onDelete,
    required this.onSubmit,
    this.canSubmit = false,
    super.key,
  });

  final int entered;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final bool canSubmit;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '$entered of ${MpinService.maxLength} digits entered',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < MpinService.maxLength; i++)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < entered ? colors.primary : Colors.transparent,
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final row in _rows)
          Row(
            children: [
              for (final digit in row)
                Expanded(child: _DigitKey(digit: digit, onPressed: onDigit)),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: IconButton(
                tooltip: 'Delete digit',
                onPressed: entered == 0 ? null : onDelete,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
            Expanded(child: _DigitKey(digit: '0', onPressed: onDigit)),
            Expanded(
              child: IconButton(
                tooltip: 'Unlock',
                onPressed: canSubmit ? onSubmit : null,
                icon: const Icon(Icons.check_circle_outline),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.onPressed});

  final String digit;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => onPressed(digit),
      style: TextButton.styleFrom(
        minimumSize: const Size(72, 56),
        textStyle: Theme.of(context).textTheme.headlineSmall,
      ),
      child: Text(digit),
    );
  }
}
