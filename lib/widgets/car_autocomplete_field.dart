import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

/// Reusable autocomplete field for car brands or models.
/// Uses Flutter's [Autocomplete] with a custom dark-theme-aware dropdown.
/// Syncs with the external [controller] so programmatic text changes show up.
class CarAutocompleteField extends StatefulWidget {
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
  State<CarAutocompleteField> createState() => _CarAutocompleteFieldState();
}

class _CarAutocompleteFieldState extends State<CarAutocompleteField> {
  TextEditingController? _autoController;

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChanged);
    super.dispose();
  }

  void _onExternalChanged() {
    final auto = _autoController;
    if (auto == null) return;
    if (auto.text != widget.controller.text) {
      auto.text = widget.controller.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.controller.removeListener(_onExternalChanged);
    widget.controller.addListener(_onExternalChanged);

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.controller.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return widget.optionsBuilder(textEditingValue.text);
      },
      onSelected: (selection) {
        widget.controller.text = selection;
        widget.onSelected?.call(selection);
      },
      fieldViewBuilder: (
        context,
        textController,
        focusNode,
        onFieldSubmitted,
      ) {
        _autoController = textController;
        if (textController.text != widget.controller.text) {
          textController.text = widget.controller.text;
        }
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          enabled: widget.enabled,
          validator: widget.validator,
          decoration: AppStyles.inputDecorationFor(
            context,
            widget.label,
            hint: widget.hint,
            icon: widget.icon,
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => widget.controller.text = v,
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
