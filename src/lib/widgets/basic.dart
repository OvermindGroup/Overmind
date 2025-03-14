import 'package:flutter/material.dart';

Widget buildSlider(String label, int value, double maxValue, Function(double) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white70)),
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

Widget buildDropdown(String label, dynamic value, List<dynamic> items, Function(dynamic) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white70)),
      DropdownButton(
        value: value,
        items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item.toString()),
        )).toList(),
        onChanged: onChanged,
        dropdownColor: Colors.grey[850],
        style: TextStyle(color: Colors.white),
      ),
    ],
  );
}

Widget buildTextField(String label, TextEditingController controller) {
  return TextField(
    controller: controller,
    obscureText: true,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white30),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueAccent),
      ),
    ),
    style: TextStyle(color: Colors.white),
  );
}

Widget buildBalanceInfo(double totalBalance, double availableBalance, double unrealizedProfit, int numberOfPositions) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _buildBalanceRow('Total Balance:', '\$${totalBalance.toStringAsFixed(2)}', Colors.white),
      _buildBalanceRow('Available Balance:', '\$${availableBalance.toStringAsFixed(2)}', Colors.white),
      _buildBalanceRow('Unrealized Profit:', '\$${unrealizedProfit.toStringAsFixed(4)}', unrealizedProfit >= 0 ? Colors.green : Colors.red),
      _buildBalanceRow('Open Positions:', numberOfPositions.toString(), Colors.white),
    ],
  );
}

Widget _buildBalanceRow(String label, String value, Color color) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.start, // Align everything to the start
    children: [
      Expanded(
        flex: 4, // Give more space to the label
        child: Text(
          label,
          style: TextStyle(color: Colors.white),
        ),
      ),
      Expanded(
        flex: 2, // Less space for the value
        child: Text(
          value,
          style: TextStyle(color: color),
          textAlign: TextAlign.right, // Align value to the right within its space
        ),
      ),
    ],
  );
}
