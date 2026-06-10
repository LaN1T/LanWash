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
  late final TextEditingController _innerController;

  @override
  void initState() {
    super.initState();
    _innerController = TextEditingController(text: widget.controller.text);
    widget.controller.addListener(_onExternalChanged);
    _innerController.addListener(_onInnerChanged);
  }

  @override
  void didUpdateWidget(covariant CarAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onExternalChanged);
      widget.controller.addListener(_onExternalChanged);
      _syncFromExternal();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalChanged);
    _innerController.removeListener(_onInnerChanged);
    _innerController.dispose();
    super.dispose();
  }

  void _onExternalChanged() {
    if (_innerController.text != widget.controller.text) {
      _innerController.text = widget.controller.text;
      // Keep cursor at the end when text is set programmatically.
      _innerController.selection = TextSelection.collapsed(
        offset: _innerController.text.length,
      );
    }
  }

  void _onInnerChanged() {
    if (widget.controller.text != _innerController.text) {
      widget.controller.text = _innerController.text;
    }
  }

  void _syncFromExternal() {
    _innerController.text = widget.controller.text;
    _innerController.selection = TextSelection.collapsed(
      offset: _innerController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _innerController.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return widget.optionsBuilder(textEditingValue.text);
      },
      onSelected: (selection) {
        _innerController.text = selection;
        widget.onSelected?.call(selection);
      },
      fieldViewBuilder: (
        context,
        textController,
        focusNode,
        onFieldSubmitted,
      ) {
        // Use the inner controller so Autocomplete stays in sync with us.
        if (textController != _innerController) {
          textController.text = _innerController.text;
        }
        return TextFormField(
          controller: _innerController,
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
