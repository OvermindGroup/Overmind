import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pluto_menu_bar/pluto_menu_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/log.dart';

/// Menu across the top of the dashboard: portfolio actions, history, keys and
/// the symbol the chart shows.
class TopMenuBar extends StatefulWidget {
  const TopMenuBar({
    super.key,
    required this.onOptimizedPortfolio,
    required this.onTradeHistory,
    required this.onOptimizationSettings,
    required this.onTrainPortfolio,
    required this.onTrainSubparModels,
    required this.onResetPortfolio,
    required this.onResetSubparModels,
    required this.onApiKeys,
    required this.onToggleAutoTrade,
    required this.onSymbolSelected,
    required this.symbols,
    required this.selectedSymbol,
    required this.isAutoTrade,
  });

  final VoidCallback onOptimizedPortfolio;
  final VoidCallback onTradeHistory;
  final VoidCallback onOptimizationSettings;
  final VoidCallback onTrainPortfolio;
  final VoidCallback onTrainSubparModels;
  final VoidCallback onResetPortfolio;
  final VoidCallback onResetSubparModels;
  final VoidCallback onApiKeys;
  final VoidCallback onToggleAutoTrade;
  final ValueChanged<String> onSymbolSelected;

  final List<String> symbols;
  final String selectedSymbol;

  /// Controls the label of the auto-trade entry so the menu says what pressing
  /// it will do.
  final bool isAutoTrade;

  static const String _upgradeUrl =
      'https://buy.stripe.com/test_9AQ8yF0XIa1t4iQ3cc';
  static const String _issuesUrl =
      'https://github.com/OvermindGroup/Overmind/issues';

  @override
  State<TopMenuBar> createState() => _TopMenuBarState();
}

class _TopMenuBarState extends State<TopMenuBar> {
  late String _selectedSymbol = widget.selectedSymbol;

  /// Built once; the auto-trade entry is the only item whose label changes.
  late List<PlutoMenuItem> _menus;

  @override
  void initState() {
    super.initState();
    _menus = _buildMenus();
  }

  @override
  void didUpdateWidget(covariant TopMenuBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSymbol != oldWidget.selectedSymbol) {
      setState(() => _selectedSymbol = widget.selectedSymbol);
    }
    if (widget.isAutoTrade != oldWidget.isAutoTrade) {
      setState(() => _menus = _buildMenus());
    }
  }

  void _selectSymbol(String? symbol) {
    if (symbol == null) return;
    setState(() => _selectedSymbol = symbol);
    widget.onSymbolSelected(symbol);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      logError('opening a link', 'Could not launch $uri');
    }
  }

  List<PlutoMenuItem> _buildMenus() {
    return [
      PlutoMenuItem(
        title: 'Dashboard',
        children: [
          PlutoMenuItem(
              title: 'Trading Dashboard', onTap: widget.onOptimizedPortfolio),
          PlutoMenuItem(title: 'Trade History', onTap: widget.onTradeHistory),
          PlutoMenuItem(
            title: widget.isAutoTrade
                ? 'Stop Automated Trading'
                : 'Start Automated Trading',
            onTap: widget.onToggleAutoTrade,
          ),
        ],
      ),
      PlutoMenuItem(
        title: 'Training',
        children: [
          PlutoMenuItem(
              title: 'Train Full Portfolio', onTap: widget.onTrainPortfolio),
          PlutoMenuItem(
              title: 'Train Subpar Models', onTap: widget.onTrainSubparModels),
        ],
      ),
      PlutoMenuItem(
        title: 'Reset',
        children: [
          PlutoMenuItem(
              title: 'Reset Portfolio', onTap: widget.onResetPortfolio),
          PlutoMenuItem(
              title: 'Reset Subpar Models', onTap: widget.onResetSubparModels),
        ],
      ),
      PlutoMenuItem(
          title: 'Optimization Settings', onTap: widget.onOptimizationSettings),
      PlutoMenuItem(title: 'API Keys', onTap: widget.onApiKeys),
      PlutoMenuItem(
          title: 'Go PRO', onTap: () => _open(TopMenuBar._upgradeUrl)),
      PlutoMenuItem(
          title: 'Report Issue', onTap: () => _open(TopMenuBar._issuesUrl)),
      PlutoMenuItem(
        title: 'Exit',
        onTap: () {
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else if (Platform.isWindows || Platform.isMacOS) {
            exit(0);
          }
        },
      ),
    ];
  }

  Widget _symbolDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButton<String>(
          value: _selectedSymbol,
          hint: const Text('BTCUSDT', style: TextStyle(color: Colors.white)),
          dropdownColor: _background,
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          underline: const SizedBox(),
          isExpanded: true,
          onChanged: _selectSymbol,
          items: [
            for (final symbol in widget.symbols)
              DropdownMenuItem<String>(
                value: symbol,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(symbol),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const Color _background = Color(0xFF141218);

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
                backgroundColor: _background,
                itemStyle: const PlutoMenuItemStyle(
                  activatedColor: Colors.white,
                  indicatorColor: Colors.deepOrange,
                  textStyle: TextStyle(color: Colors.white),
                  iconColor: Colors.white,
                  moreIconColor: Colors.white,
                ),
                menus: _menus,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 160, child: _symbolDropdown()),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
