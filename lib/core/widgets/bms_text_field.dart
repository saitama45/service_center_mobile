import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

class BmsTextField extends StatefulWidget {
  const BmsTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.autofocus = false,
    this.focusNode,
    this.isRequired = false,
  });

  final String label;
  final bool isRequired;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<BmsTextField> createState() => _BmsTextFieldState();
}

class _BmsTextFieldState extends State<BmsTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.isRequired
            ? RichText(
                text: TextSpan(
                  style: AppTextStyles.label,
                  children: [
                    TextSpan(text: widget.label),
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ],
                ),
              )
            : Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: 4),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _obscure,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          maxLines: _obscure ? 1 : widget.maxLines,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          autofocus: widget.autofocus,
          focusNode: widget.focusNode,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.mediumGray.withValues(alpha: 0.7)),
            errorText: widget.errorText,
            errorStyle: AppTextStyles.errorText,
            errorMaxLines: 3,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon,
                    color: AppColors.primaryBlue, size: 20)
                : null,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.mediumGray,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                    )
                  : widget.suffixIcon,
              filled: true,
              fillColor:
                  widget.enabled ? AppColors.white : AppColors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(
                    color: AppColors.primaryBlue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                borderSide:
                    const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
            ),
          ),
      ],
    );
  }
}

