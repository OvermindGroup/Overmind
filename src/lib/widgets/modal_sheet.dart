import 'package:flutter/material.dart';

/// Opens a bottom sheet whose content decides its own size.
void showSheet(BuildContext context, Widget content) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => content,
  );
}

/// Shell every modal shares: a centered, scrollable panel with a title.
///
/// The width shrinks on narrow screens so the sheet stays readable on mobile.
class ModalSheet extends StatelessWidget {
  const ModalSheet({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  static const double _wideBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FractionallySizedBox(
          widthFactor: constraints.maxWidth > _wideBreakpoint ? 0.8 : 1.0,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
