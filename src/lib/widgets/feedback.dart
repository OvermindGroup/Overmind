import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Toast surface shared by every screen and callback.
///
/// Toasts are raised from code without a build context (services, timers), so
/// the surface is global and initialised once from the app's navigator.
final FToast fToast = FToast();

/// A trading message stays on screen long enough to read while the dashboard
/// keeps updating around it.
const Duration toastDuration = Duration(seconds: 10);

void initToasts(BuildContext context) => fToast.init(context);

void showToast(String message) {
  fToast.removeCustomToast();
  fToast.showToast(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey[600],
      ),
      child: Text(message,
          style: const TextStyle(color: Colors.white, fontSize: 24)),
    ),
    gravity: ToastGravity.BOTTOM,
    toastDuration: toastDuration,
    isDismissible: true,
  );
}

/// Snack bars need a context, so they live next to toasts rather than being
/// re-typed at every call site.
void showSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = Colors.white,
  Duration duration = const Duration(seconds: 5),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      duration: duration,
    ),
  );
}
