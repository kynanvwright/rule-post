// flutter_app/lib/content/widgets/prompt_stage_length.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


// Used in rules committee function to alter stage lengths
Future<int?> promptStageLength(
  BuildContext context, {
  required Future<int> Function() loadCurrent,
  int min = 1,
  int max = 30,
}) async {
  final result = await showDialog<int?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      // 👇 correctly *call* the function
      final future = loadCurrent();
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();

      return FutureBuilder<int>(
        future: future,
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const AlertDialog(
              content: SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
            );
          }

          controller.text = snap.data!.toString();

          return AlertDialog(
            title: const Text('Change Stage Length'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Working days',
                  helperText: 'Set the number of working days for major stages',
                  helperMaxLines: 2,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a number';
                  final n = int.tryParse(v);
                  if (n == null) return 'Invalid number';
                  if (n < min || n > max) return 'Must be between $min and $max';
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(int.parse(controller.text));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  return result;
}