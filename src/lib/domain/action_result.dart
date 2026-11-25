/// Outcome of an action the user triggered, ready to be shown as a toast.
class ActionResult {
  const ActionResult(this.message, {this.success = true});

  static ActionResult failure(String message) =>
      ActionResult(message, success: false);

  final String message;
  final bool success;
}
