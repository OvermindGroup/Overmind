// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, exit;
import 'package:pluto_menu_bar/pluto_menu_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class TopMenuBar extends StatefulWidget {
  final VoidCallback onTrainPortfolio;
  final VoidCallback onTrainModels;
  final VoidCallback onOptimizedPortfolio;
  final VoidCallback onResetPortfolio;
  final VoidCallback onResetModels;
  final VoidCallback onTradeHistory;
  final VoidCallback onOptimizationSettings;
  // final VoidCallback onManualUpdate;
  final VoidCallback onApiKeys;
  final VoidCallback onAutoTrade;
  final Function(String) onSymbolSelected;
  final List<String> symbols;
  final String selectedSymbol;

  const TopMenuBar({
      super.key,
      required this.onTrainPortfolio,
      required this.onTrainModels,
      required this.onOptimizedPortfolio,
      required this.onResetPortfolio,
      required this.onResetModels,
      required this.onOptimizationSettings,
      required this.onTradeHistory,
      // required this.onManualUpdate,
      required this.onApiKeys,
      required this.onAutoTrade,
      required this.onSymbolSelected,
      required this.symbols,
      required this.selectedSymbol,
  });

  @override
  State<TopMenuBar> createState() => _TopMenuBarState();
}

class _TopMenuBarState extends State<TopMenuBar> {
  late final List<PlutoMenuItem> _menus;
  String? selectedSymbol;

  @override
  void initState() {
    super.initState();
    // Initialize selectedSymbol with the value passed from the parent widget
    selectedSymbol = widget.selectedSymbol;
    _menus = _makeMenus(context);
  }

  @override
  void didUpdateWidget(covariant TopMenuBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent updates the selectedSymbol, update it in this widget
    if (widget.selectedSymbol != oldWidget.selectedSymbol) {
      setState(() {
          selectedSymbol = widget.selectedSymbol;
      });
    }
  }

  void _onSymbolChanged(String? newValue) {
    setState(() {
        selectedSymbol = newValue; // Update local selectedSymbol
    });
    if (newValue != null) {
      widget.onSymbolSelected(newValue); // Notify parent of the change
    }
  }

  void message(context, String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(text),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showComingSoon(BuildContext context) {
    final snackBar = SnackBar(
      content: Text('Coming Soon'),
      duration: Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Widget _buildSymbolsDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF141218), // Dark background color
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: DropdownButton<String>(
          value: selectedSymbol,
          hint: Text('BTCUSDT', style: TextStyle(color: Colors.white)),
          dropdownColor: Color(0xFF141218),
          style: TextStyle(color: Colors.white),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white),
          underline: SizedBox(), // Removes the default underline
          isExpanded: true, // Makes the button take full width of its parent
          onChanged: _onSymbolChanged, // Call the change handler
          items: widget.symbols.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(value),
                ),
              );
          }).toList(),
        ),
      ),
    );
  }

  List<PlutoMenuItem> _makeMenus(BuildContext context) {
    return [
      PlutoMenuItem(
        title: 'Trading Dashboard',
        onTap: widget.onOptimizedPortfolio,
      ),
      PlutoMenuItem(
        title: 'Trade History',
        onTap: widget.onTradeHistory,
      ),
      // PlutoMenuItem(
      //   title: 'Current Portfolio',
      //   children: [
      //     PlutoMenuItem(
      //       title: 'Open Positions',
      //       onTap: widget.onPositions,
      //     ),
      //     // PlutoMenuItem.widget(widget: Text(),) ! Disabled
      //     PlutoMenuItem(
      //       title: 'Trade History',
      //       onTap: widget.onTradeHistory,
      //     ),
      //   ],
      // ),
      // PlutoMenuItem(
      //   title: 'Portfolio Optimization',
      //   children: [
      //     PlutoMenuItem(
      //       title: 'Visualization',
      //       children: [
      //         PlutoMenuItem(
      //           title: 'Show Portfolio',
      //           onTap: widget.onOptimizedPortfolio,
      //         ),
      //       ],
      //     ),
      //     PlutoMenuItem(
      //       title: 'Training',
      //       children: [
      //         PlutoMenuItem(
      //           title: 'Train Full Portfolio',
      //           onTap: widget.onTrainPortfolio,
      //         ),
      //         PlutoMenuItem(
      //           title: 'Train Subpar Models',
      //           onTap: widget.onTrainModels,
      //         ),
      //       ],
      //     ),
      //     PlutoMenuItem(
      //       title: 'Reset',
      //       children: [
      //         PlutoMenuItem(
      //           title: 'Reset Portfolio',
      //           onTap: widget.onResetPortfolio,
      //         ),
      //         PlutoMenuItem(
      //           title: 'Reset Subpar Models',
      //           onTap: widget.onResetModels,
      //         ),
      //       ],
      //     ),
      //     PlutoMenuItem(
      //       title: 'Settings',
      //       onTap: widget.onOptimizationSettings,
      //     ),
      //   ],
      // ),
      // PlutoMenuItem(
      //   title: 'Update Portfolio',
      //   children: [
      //     PlutoMenuItem(
      //       title: 'Trade Once',
      //       onTap: widget.onManualUpdate,
      //     ),
      //     // PlutoMenuItem.widget(
      //     //   widget: Text('Automated Updating')
      //     // ),
      //     PlutoMenuItem(
      //       title: 'Toggle Automated Trading',
      //       onTap: widget.onAutoTrade,
      //     ),
      //   ],
      // ),
      PlutoMenuItem(
        title: 'API Keys',
        onTap: widget.onApiKeys,
      ),
      PlutoMenuItem(
        title: 'Go PRO',
        onTap: () async {
          const url = 'https://buy.stripe.com/test_9AQ8yF0XIa1t4iQ3cc';
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } else {
            print('Could not launch $url');
          }
        },
      ),
      PlutoMenuItem(
        title: 'Exit',
        onTap: () async {
          if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else if (Platform.isWindows || Platform.isMacOS) {
              exit(0);
            }
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: PlutoMenuBar(
                mode: PlutoMenuBarMode.hover,
                backgroundColor: Color(0xFF141218),
                itemStyle: const PlutoMenuItemStyle(
                  activatedColor: Colors.white,
                  indicatorColor: Colors.deepOrange,
                  textStyle: TextStyle(color: Colors.white),
                  iconColor: Colors.white,
                  moreIconColor: Colors.white,
                ),
                menus: _menus,
              )
            )
          ),
          SizedBox(width: 16),
          SizedBox(width: 160, child: _buildSymbolsDropdown()),
          SizedBox(width: 16),
        ]
      )
    );
  }
}
