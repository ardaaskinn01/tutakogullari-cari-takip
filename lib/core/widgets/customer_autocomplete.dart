import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/customer_service.dart';

class CustomerAutocomplete extends ConsumerWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final IconData prefixIcon;

  const CustomerAutocomplete({
    super.key,
    required this.controller,
    this.labelText = 'Müşteri Adı',
    this.validator,
    this.prefixIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerNamesAsync = ref.watch(allCustomerNamesProvider);

    return customerNamesAsync.when(
      data: (names) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: FocusNode(),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          return names.where((String option) {
            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
          });
        },
        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: textController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: labelText,
              prefixIcon: Icon(prefixIcon),
              border: const OutlineInputBorder(),
            ),
            validator: validator,
            onFieldSubmitted: (value) => onFieldSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 32,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final String option = options.elementAt(index);
                    return ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
      loading: () => TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: const Icon(Icons.person),
          border: const OutlineInputBorder(),
          suffixIcon: const SizedBox(
            width: 20,
            height: 20,
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, __) => TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: const Icon(Icons.person),
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }
}
