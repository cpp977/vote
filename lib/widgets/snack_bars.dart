import 'package:flutter/material.dart';

/// Shows [message] as an error in a floating [SnackBar].
///
/// Error snack bars use [ColorScheme.errorContainer] as background colour,
/// which is a light red in light themes and a dark red in dark themes.
/// The default [SnackBar] text colour is white, which is barely readable on
/// the light red background. Therefore the text is explicitly styled with
/// [ColorScheme.onErrorContainer], the colour designed by the Material 3
/// palette to be readable on top of [ColorScheme.errorContainer].
void showErrorSnackBar(BuildContext context, String message) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: colorScheme.onErrorContainer),
      ),
      backgroundColor: colorScheme.errorContainer,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
