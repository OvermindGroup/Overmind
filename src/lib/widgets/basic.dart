import 'package:flutter/material.dart';

/// A slider whose label shows the current value.
Widget sliderRow(
  String label,
  int value,
  double maxValue,
  ValueChanged<double> onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      Slider(
        value: value.toDouble(),
        min: 1,
        max: maxValue,
        divisions: 99,
        label: value.round().toString(),
        onChanged: onChanged,
      ),
    ],
  );
}

/// A labelled dropdown, used for the settings that only accept fixed values.
Widget dropdownRow<T>(
  String label,
  T value,
  List<T> items,
  ValueChanged<T?> onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      DropdownButton<T>(
        value: value,
        items: [
          for (final item in items)
            DropdownMenuItem<T>(value: item, child: Text(item.toString())),
        ],
        onChanged: onChanged,
        dropdownColor: Colors.grey[850],
        style: const TextStyle(color: Colors.white),
      ),
    ],
  );
}

/// A masked input for credentials.
Widget secretField(String label, TextEditingController controller) {
  return TextField(
    controller: controller,
    obscureText: true,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white30),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueAccent),
      ),
    ),
    style: const TextStyle(color: Colors.white),
  );
}

/// Label on the left, action on the right.
Widget labeledButtonRow({
  required String label,
  required String buttonText,
  required IconData icon,
  required VoidCallback onPressed,
  Color? buttonColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white),
            label:
                Text(buttonText, style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor ?? Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A number input on a rounded panel, paired with its label.
///
/// [isInteger] selects the keyboard and the validation rule, which is all that
/// differed between the allocation and leverage fields.
Widget numberFieldRow({
  required String label,
  required TextEditingController controller,
  required bool isInteger,
  required ValueChanged<String> onChanged,
}) {
  return Row(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
      Expanded(
        flex: 2,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(
                decimal: !isInteger,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white54),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                final parsed =
                    isInteger ? int.tryParse(value) : double.tryParse(value);
                return parsed == null ? 'Invalid number' : null;
              },
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ],
  );
}

/// A short warning shown under a heading when required input is missing.
Widget missingInputWarning(String message) {
  return Text(
    message,
    style: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
  );
}
