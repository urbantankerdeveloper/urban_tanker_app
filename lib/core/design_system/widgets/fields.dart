import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';
import '../typography.dart';

/// Text field with the design-system decoration (from the theme) and a floating
/// label. Pass `prefix` / `suffix` widgets, such as an icon or a visibility toggle.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
    );
  }
}

/// Six-box one-time-code input. A transparent text field sits over the boxes,
/// so the platform keyboard, paste and SMS autofill still work.
class OtpField extends StatefulWidget {
  const OtpField({
    required this.onChanged,
    super.key,
    this.length = 6,
    this.onCompleted,
    this.autofocus = false,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_rebuild)
      ..dispose();
    _focusNode
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _handleChanged(String value) {
    widget.onChanged(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = _controller.text;
    // The box after the last digit is the active one; the last box stays
    // active once the code is full.
    final active = math.min(text.length, widget.length - 1);
    return Semantics(
      textField: true,
      label: 'One-time code, ${widget.length} digits',
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: AppRadius.inputBorder,
                            border: Border.all(
                              color: _focusNode.hasFocus && i == active
                                  ? colors.primary
                                  : colors.hairline,
                              width: _focusNode.hasFocus && i == active ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              i < text.length ? text[i] : '',
                              style: AppTypography.numeric(
                                Theme.of(context).textTheme.titleLarge!,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned.fill(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                style: const TextStyle(color: Colors.transparent),
                cursorColor: Colors.transparent,
                onChanged: _handleChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Money or count text with tabular figures so amounts align in columns.
class AmountText extends StatelessWidget {
  const AmountText(this.text, {super.key, this.style, this.large = false});

  /// Already formatted, for example "₹1,250".
  final String text;
  final TextStyle? style;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final base = style ?? (large ? theme.headlineMedium! : theme.titleMedium!);
    return Text(text, maxLines: 1, style: AppTypography.numeric(base));
  }
}

/// Animates a number to its new [value] and shows it with [format].
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount({
    required this.value,
    required this.format,
    super.key,
    this.style,
    this.large = false,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: AppMotion.duration(context, AppMotion.slow),
      curve: AppMotion.curve,
      builder: (context, animated, _) => AmountText(
        format(animated),
        style: style,
        large: large,
      ),
    );
  }
}
