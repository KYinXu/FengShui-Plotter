import 'package:flutter/material.dart';

Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        title: title,
        content: content,
        actions: actions,
      );
    },
  );
}

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: content,
      actions: actions,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
} 