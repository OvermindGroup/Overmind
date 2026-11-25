import 'package:flutter/material.dart';
import 'package:flutter_sizer/flutter_sizer.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'screens/home_screen.dart';

/// Navigator the app is built around.
///
/// Toasts and update prompts are raised from code that has no build context, so
/// they reach the UI through this key.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Root widget: a dark, full-screen Material app that ignores text scaling so
/// the trading dashboard keeps its layout on every device.
class Overmind extends StatelessWidget {
  const Overmind({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterSizer(
      builder: (context, orientation, screenType) {
        return MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1)),
          child: MaterialApp(
            builder: FToastBuilder(),
            title: 'Overmind',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            navigatorKey: navigatorKey,
            home: const HomeScreen(),
          ),
        );
      },
    );
  }
}
