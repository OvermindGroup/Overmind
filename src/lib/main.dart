import 'dart:io' show Platform;

import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.html) 'package:window_manager/window_manager_stub.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The dashboard is a wide table of numbers, so it is landscape-only on mobile.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);

  runApp(const Overmind());

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  }

  FullScreenWindow.setFullScreen(true);
}
