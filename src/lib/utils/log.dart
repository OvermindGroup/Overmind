import 'package:flutter/foundation.dart';

/// Single logging seam.
///
/// Every service reports problems through this instead of scattering `print`,
/// so the output is tagged and can be redirected in tests.
void log(String message) => debugPrint('[overmind] $message');

void logError(String context, Object error) =>
    debugPrint('[overmind] $context: $error');
