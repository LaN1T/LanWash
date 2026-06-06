import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

/// Reusable autocomplete field for car brands or models.
/// Uses Flutter's [Autocomplete] with a custom dark-theme-aware dropdown.
class CarAutocompleteField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final TextEditingController controller;
  final List<String> Function(String) optionsBuilder;
  final bool enabled;
  final void Function(String)? onSelected;
  final String? Function(String?)? validator;

  const CarAutocompleteField({
    super.key,
    required this.label,
    this.hint,
    required this.icon,
    required this.controller,
    required this.optionsBuilder,
    this.enabled = true,
    this.onSelected,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return optionsBuilder(textEditingValue.text);
      },
      onSelected: (selection) {
        controller.text = selection;
        onSelected?.call(selection);
      },
      fieldViewBuilder: (
        context,
        textController,
        focusNode,
        onFieldSubmitted,
      ) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          enabled: enabled,
          validator: validator,
          decoration: AppStyles.inputDecorationFor(
            context,
            label,
            hint: hint,
            icon: icon,
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => controller.text = v,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: AppStyles.adaptiveCard(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      option,
                      style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
