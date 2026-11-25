import 'package:flutter/material.dart';

import '../domain/api_keys.dart';
import 'basic.dart';
import 'feedback.dart';
import 'modal_sheet.dart';

/// Collects and stores the Binance and Overmind keys.
///
/// The controllers belong to this widget, so they are disposed with it; the
/// screen used to keep them alive for its whole lifetime while only this sheet
/// ever read them.
class ApiKeysModal extends StatefulWidget {
  const ApiKeysModal({
    required this.keys,
    required this.onRequestFreeTierKey,
    required this.onSave,
    super.key,
  });

  final ApiKeys keys;

  /// Ask the server for a free-tier key. Throws when the request fails.
  final Future<String> Function() onRequestFreeTierKey;

  /// Persists the keys the user typed, then the screen loads with them.
  final Future<void> Function(ApiKeys keys) onSave;

  @override
  State<ApiKeysModal> createState() => _ApiKeysModalState();
}

class _ApiKeysModalState extends State<ApiKeysModal> {
  late final TextEditingController _binanceKey =
      TextEditingController(text: widget.keys.binanceApiKey);
  late final TextEditingController _binanceSecret =
      TextEditingController(text: widget.keys.binanceApiSecret);
  late final TextEditingController _overmindKey =
      TextEditingController(text: widget.keys.overmindApiKey);

  bool _busy = false;

  ApiKeys get _typedKeys => ApiKeys(
        binanceApiKey: _binanceKey.text.trim(),
        binanceApiSecret: _binanceSecret.text.trim(),
        overmindApiKey: _overmindKey.text.trim(),
      );

  @override
  void dispose() {
    _binanceKey.dispose();
    _binanceSecret.dispose();
    _overmindKey.dispose();
    super.dispose();
  }

  Future<void> _requestFreeTierKey() async {
    setState(() => _busy = true);
    try {
      final key = await widget.onRequestFreeTierKey();
      if (!mounted) return;
      setState(() {
        _overmindKey.text = key;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnackBar(context, 'Failed to get free-tier key: $error');
    }
  }

  Future<void> _storeKeys() async {
    setState(() => _busy = true);
    try {
      await widget.onSave(_typedKeys);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnackBar(context, 'Failed to store keys: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _typedKeys;

    return ModalSheet(
      title: 'API Keys',
      children: [
        if (!typed.hasBinance) ...[
          missingInputWarning('Please provide your Binance API key and secret'),
          const SizedBox(height: 12),
        ],
        secretField('Binance API Key', _binanceKey),
        const SizedBox(height: 16),
        secretField('Binance API Secret', _binanceSecret),
        const SizedBox(height: 8),
        if (!typed.hasOvermind) ...[
          missingInputWarning('Please provide your Overmind PRO API key'),
          const SizedBox(height: 8),
        ],
        secretField('Overmind API Key', _overmindKey),
        const SizedBox(height: 16),
        if (!typed.hasOvermind)
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Or request a free-tier key:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              ElevatedButton(
                onPressed: _busy ? null : _requestFreeTierKey,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                ),
                child: const Text('Get Free-Tier Key'),
              ),
            ],
          ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _busy ? null : _storeKeys,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: const Text('Store Securely'),
        ),
      ],
    );
  }
}
