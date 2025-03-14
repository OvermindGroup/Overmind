import 'dart:math';

import 'package:flutter/material.dart';

import 'candle_data.dart';
import 'painter_params.dart';

typedef TimeLabelGetter = String Function(int timestamp, int visibleDataCount);
typedef PriceLabelGetter = String Function(double price);
typedef OverlayInfoGetter = Map<String, String> Function(CandleData candle);

class ChartPainter extends CustomPainter {
  final PainterParams params;
  final TimeLabelGetter getTimeLabel;
  final PriceLabelGetter getPriceLabel;
  final OverlayInfoGetter getOverlayInfo;

  ChartPainter({
      required this.params,
      required this.getTimeLabel,
      required this.getPriceLabel,
      required this.getOverlayInfo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw time labels (dates) & price labels
    _drawTimeLabels(canvas, params);
    _drawPriceGridAndLabels(canvas, params);

    // Draw prices, volumes & trend line
    canvas.save();
    canvas.clipRect(Offset.zero & Size(params.chartWidth, params.chartHeight));
    // canvas.drawRect(
    //   // apply yellow tint to clipped area (for debugging)
    //   Offset.zero & Size(params.chartWidth, params.chartHeight),
    //   Paint()..color = Colors.yellow[100]!,
    // );
    canvas.translate(params.xShift, 0);
    for (int i = 0; i < params.candles.length; i++) {
      _drawSingleDay(canvas, params, i);
    }
    canvas.restore();

    // Draw tap highlight & overlay
    if (params.tapPosition != null) {
      if (params.tapPosition!.dx < params.chartWidth) {
        _drawTapHighlightAndOverlay(canvas, params);
      }
    }
  }

  void _drawTimeLabels(canvas, PainterParams params) {
    // We draw one time label per 90 pixels of screen width
    final lineCount = params.chartWidth ~/ 90;
    final gap = 1 / (lineCount + 1);
    for (int i = 1; i <= lineCount; i++) {
      double x = i * gap * params.chartWidth;
      final index = params.getCandleIndexFromOffset(x);
      if (index < params.candles.length) {
        final candle = params.candles[index];
        final visibleDataCount = params.candles.length;
        final timeTp = TextPainter(
          text: TextSpan(
            text: getTimeLabel(candle.timestamp, visibleDataCount),
            style: params.style.timeLabelStyle,
          ),
        )
        ..textDirection = TextDirection.ltr
        ..layout();

        // Align texts towards vertical bottom
        final topPadding = params.style.timeLabelHeight - timeTp.height;
        timeTp.paint(
          canvas,
          Offset(x - timeTp.width / 2, params.chartHeight + topPadding),
        );
      }
    }
  }

  void _drawPriceGridAndLabels(canvas, PainterParams params) {
    [0.0, 0.25, 0.5, 0.75, 1.0]
    .map((v) => ((params.maxPrice - params.minPrice) * v) + params.minPrice)
    .forEach((y) {
        canvas.drawLine(
          Offset(0, params.fitPrice(y)),
          Offset(params.chartWidth, params.fitPrice(y)),
          Paint()
          ..strokeWidth = 0.5
          ..color = params.style.priceGridLineColor,
        );
        final priceTp = TextPainter(
          text: TextSpan(
            text: getPriceLabel(y),
            style: params.style.priceLabelStyle,
          ),
        )
        ..textDirection = TextDirection.ltr
        ..layout();
        priceTp.paint(
          canvas,
          Offset(
            params.chartWidth + 4,
            params.fitPrice(y) - priceTp.height / 2,
        ));
    });
  }

  Color getAmheragColor(double x, double min, double max, String theme) {
    if (x <= min) return _getColorStart(theme);
    if (x >= max) return _getColorEnd(theme);

    // Normalize the value between 0 and 1
    double normalized = (x - min) / (max - min);

    // Interpolate color based on the selected theme
    return Color.lerp(_getColorStart(theme), _getColorEnd(theme), normalized)!;
  }

  Color _getColorStart(String theme) {
    switch (theme) {
      case 'Solana':
      return Color(0xFFDC1FFF);
      case 'Hellfire':
      return Colors.red[900]!;
      case 'CoolWarm':
      return Colors.blue[900]!;
      case 'MonoDark':
      return Colors.grey[900]!;
      case 'MonoLight':
      return Colors.grey[200]!;
      case 'Rainbow':
      return Colors.purple;
      case 'Ocean':
      return Colors.cyan[900]!;
      case 'Sunrise':
      return Colors.orange[900]!;
      case 'Forest':
      return Colors.green[900]!;
      case 'Diverging':
      return Colors.blue[900]!;
      default:
      return Colors.grey[200]!; // Default to a neutral gradient
    }
  }

  Color _getColorEnd(String theme) {
    switch (theme) {
      case 'Solana':
      return Color(0xFF00FFA3);
      case 'Hellfire':
      return Colors.yellow;
      case 'CoolWarm':
      return Colors.red[900]!;
      case 'MonoDark':
      return Colors.black;
      case 'MonoLight':
      return Colors.white;
      case 'Rainbow':
      return Colors.red;
      case 'Ocean':
      return Colors.lightBlue[100]!;
      case 'Sunrise':
      return Colors.pink[300]!;
      case 'Forest':
      return Colors.green[300]!;
      case 'Diverging':
      return Colors.red[900]!;
      default:
      return Colors.grey[900]!; // Default to a neutral gradient
    }
  }

  Map<String, Color> getLineColors(String theme) {
    switch (theme) {
      case 'Solana':
      return {
        'takeProfit': Colors.green[700]!,
        'stopLoss': Colors.pink[700]!,
        'entryPrice': Colors.blueAccent,
        'bullishCandle': Colors.white,
        'bearishCandle': Colors.black,
        'volumeBar': Colors.white,
      };
      case 'Hellfire':
      return {
        'takeProfit': Colors.grey[200]!,
        'stopLoss': Colors.black,
        'entryPrice': Colors.blue[700]!,
        'bullishCandle': Colors.white,
        'bearishCandle': Colors.black,
        'volumeBar': Colors.white,
      };
      case 'CoolWarm':
      return {
        'takeProfit': Colors.lightGreen,
        'stopLoss': Colors.brown[800]!,
        'entryPrice': Colors.yellow[700]!,
        'bullishCandle': Colors.green[600]!,
        'bearishCandle': Colors.red[900]!,
        'volumeBar': Colors.blueAccent,
      };
      case 'MonoDark':
      return {
        'takeProfit': Colors.lightGreenAccent,
        'stopLoss': Colors.redAccent,
        'entryPrice': Colors.white,
        'bullishCandle': Colors.greenAccent,
        'bearishCandle': Colors.grey[600]!,
        'volumeBar': Colors.blueGrey,
      };
      case 'MonoLight':
      return {
        'takeProfit': Colors.green[700]!,
        'stopLoss': Colors.red[800]!,
        'entryPrice': Colors.black,
        'bullishCandle': Colors.grey[700]!,
        'bearishCandle': Colors.red[800]!,
        'volumeBar': Colors.grey[500]!,
      };
      case 'Rainbow':
      return {
        'takeProfit': Colors.green[400]!,
        'stopLoss': Colors.brown[900]!,
        'entryPrice': Colors.yellow[800]!,
        'bullishCandle': Colors.green[500]!,
        'bearishCandle': Colors.red[600]!,
        'volumeBar': Colors.deepPurpleAccent,
      };
      case 'Ocean':
      return {
        'takeProfit': Colors.lime[700]!,
        'stopLoss': Colors.purple[800]!,
        'entryPrice': Colors.teal[300]!,
        'bullishCandle': Colors.tealAccent,
        'bearishCandle': Colors.blue[900]!,
        'volumeBar': Colors.lightBlueAccent,
      };
      case 'Sunrise':
      return {
        'takeProfit': Colors.teal[400]!,
        'stopLoss': Colors.purple[900]!,
        'entryPrice': Colors.amber[600]!,
        'bullishCandle': Colors.orangeAccent,
        'bearishCandle': Colors.redAccent,
        'volumeBar': Colors.pinkAccent,
      };
      case 'Forest':
      return {
        'takeProfit': Colors.lightGreenAccent,
        'stopLoss': Colors.deepOrange[800]!,
        'entryPrice': Colors.brown[700]!,
        'bullishCandle': Colors.green[700]!,
        'bearishCandle': Colors.brown,
        'volumeBar': Colors.lightGreen[300]!,
      };
      case 'Diverging':
      return {
        'takeProfit': Colors.greenAccent,
        'stopLoss': Colors.deepPurple,
        'entryPrice': Colors.amber[800]!,
        'bullishCandle': Colors.lightBlueAccent,
        'bearishCandle': Colors.redAccent,
        'volumeBar': Colors.yellowAccent,
      };
      default:
      return {
        'takeProfit': Colors.white,
        'stopLoss': Colors.black,
        'entryPrice': Colors.teal,
        'bullishCandle': Colors.white,
        'bearishCandle': Colors.black,
        'volumeBar': Colors.teal,
      };
    }
  }

  void _drawSingleDay(canvas, PainterParams params, int i) {
    final candle = params.candles[i];
    final x = i * params.candleWidth * 0.98;
    final thickWidth = max(params.candleWidth * 0.8, 0.8);
    final thinWidth = max(params.candleWidth * 0.2, 0.2);
    final open = candle.open;
    final close = candle.close;
    final high = candle.high;
    final low = candle.low;
    final amheragAbove = candle.amheragAbove!.reversed.toList();
    final amheragBelow = candle.amheragBelow;
    final amheragWidth = params.candleWidth;
    final amheragHeight = params.amheragHeight;
    final amheragMax = candle.amheragMax;
    final amheragMin = candle.amheragMin;
    final tp = params.tp;
    final sl = params.sl;
    final newTp = params.newTp;
    final newSl = params.newSl;
    final entryPrice = params.entryPrice;
    final lastClose = params.lastClose;
    final theme = 'Hellfire';
    final lineColors = getLineColors(theme);

    // Draw amherag
    if (amheragAbove != null && amheragBelow != null && amheragHeight != null) {
      for (int c = 0; c < amheragAbove.length; c++) {
        // for (int c = above.length-1; c >= 0; c--) {
        canvas.drawLine(
          Offset(x, params.fitPrice(close! + amheragHeight! * c * 0.98)),
          Offset(x, params.fitPrice(close! + amheragHeight! * (c + 1) * 1.1)),
          Paint()
          ..strokeWidth = amheragWidth
          // ..color = params.style.volumeColor,
          ..color = getAmheragColor(amheragAbove![c], amheragMin!, amheragMax!, theme),
        );
      }
      // for (int c = below.length-1; c >= 0; c--) {
      for (int c = 0; c < amheragBelow.length; c++) {
        canvas.drawLine(
          Offset(x, params.fitPrice(close! + amheragHeight! * -c * 0.98)),
          Offset(x, params.fitPrice(close! + amheragHeight! * -(c + 1) * 1.1)),
          Paint()
          ..strokeWidth = amheragWidth
          // ..color = params.style.volumeColor,
          ..color = getAmheragColor(amheragBelow![c], amheragMin!, amheragMax!, theme),
        );
      }
    }
    // Draw price bar
    if (open != null && close != null) {
      // final color = open > close
      // ? params.style.priceLossColor
      // : params.style.priceGainColor;
      final color = open > close
      ? lineColors["bearishCandle"]!
      : lineColors["bullishCandle"]!;
      canvas.drawLine(
        Offset(x, params.fitPrice(open)),
        Offset(x, params.fitPrice(close)),
        Paint()
        ..strokeWidth = thickWidth
        ..color = color,
      );
      if (high != null && low != null) {
        canvas.drawLine(
          Offset(x, params.fitPrice(high)),
          Offset(x, params.fitPrice(low)),
          Paint()
          ..strokeWidth = thinWidth
          ..color = color,
        );
      }
    }
    // Draw current portfolio tp & sl
    if (tp != 0.0 && sl != 0.0) {
      canvas.drawLine(
        // Offset(x + thickWidth, params.fitPrice(lastClose! + tp)),
        // Offset(x - thickWidth, params.fitPrice(lastClose! + tp)),
        Offset(x + thickWidth, params.fitPrice(tp)),
        Offset(x - thickWidth, params.fitPrice(tp)),
        Paint()
        ..strokeWidth = 2.0
        ..color = lineColors["takeProfit"]!
        // ..color = Color(0xFF00C853),
      );
      canvas.drawLine(
        // Offset(x + thickWidth, params.fitPrice(lastClose! + sl)),
        // Offset(x - thickWidth, params.fitPrice(lastClose! + sl)),
        Offset(x + thickWidth, params.fitPrice(sl)),
        Offset(x - thickWidth, params.fitPrice(sl)),
        Paint()
        ..strokeWidth = 2.0
        ..color = lineColors["stopLoss"]!
        // ..color = Color(0xFFD50000),
      );
    }
    // Draw recommended portfolio tp & sl
    if (newTp != 0.0 && newSl != 0.0) {
      canvas.drawLine(
        Offset(x + thinWidth, params.fitPrice(lastClose! + newTp)),
        Offset(x - thinWidth, params.fitPrice(lastClose! + newTp)),
        Paint()
        ..strokeWidth = 3.0
        ..color = lineColors["takeProfit"]!,
      );
      canvas.drawLine(
        Offset(x + thinWidth, params.fitPrice(lastClose! + newSl)),
        Offset(x - thinWidth, params.fitPrice(lastClose! + newSl)),
        Paint()
        ..strokeWidth = 3.0
        ..color = lineColors["stopLoss"]!,
      );
    }
    // Draw entry price
    if (entryPrice != 0.0) {
      canvas.drawLine(
        Offset(x + thickWidth, params.fitPrice(entryPrice)),
        Offset(x - thickWidth, params.fitPrice(entryPrice)),
        Paint()
        ..strokeWidth = 2.0
        ..color = lineColors["entryPrice"]!
      );
    }
    // Draw volume bar
    final volume = candle.volume;
    if (volume != null) {
      canvas.drawLine(
        Offset(x, params.chartHeight),
        Offset(x, params.fitVolume(volume)),
        Paint()
        ..strokeWidth = thickWidth
        // ..color = params.style.volumeColor,
        ..color = lineColors["volumeBar"]!
      );
    }
    // Draw trend line
    for (int j = 0; j < candle.trends.length; j++) {
      final trendLinePaint = params.style.trendLineStyles.at(j) ??
      (Paint()
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = Colors.blue);

      final pt = candle.trends.at(j); // current data point
      final prevPt = params.candles.at(i - 1)?.trends.at(j);
      if (pt != null && prevPt != null) {
        canvas.drawLine(
          Offset(x - params.candleWidth, params.fitPrice(prevPt)),
          Offset(x, params.fitPrice(pt)),
          trendLinePaint,
        );
      }
      if (i == 0) {
        // In the front, draw an extra line connecting to out-of-window data
        if (pt != null && params.leadingTrends?.at(j) != null) {
          canvas.drawLine(
            Offset(x - params.candleWidth,
              params.fitPrice(params.leadingTrends!.at(j)!)),
            Offset(x, params.fitPrice(pt)),
            trendLinePaint,
          );
        }
      } else if (i == params.candles.length - 1) {
        // At the end, draw an extra line connecting to out-of-window data
        if (pt != null && params.trailingTrends?.at(j) != null) {
          canvas.drawLine(
            Offset(x, params.fitPrice(pt)),
            Offset(
              x + params.candleWidth,
              params.fitPrice(params.trailingTrends!.at(j)!),
            ),
            trendLinePaint,
          );
        }
      }
    }
  }

  void _drawTapHighlightAndOverlay(canvas, PainterParams params) {
    final pos = params.tapPosition!;
    final i = params.getCandleIndexFromOffset(pos.dx);
    final candle = params.candles[i];
    canvas.save();
    canvas.translate(params.xShift, 0.0);
    // Draw highlight bar (selection box)
    canvas.drawLine(
      Offset(i * params.candleWidth, 0.0),
      Offset(i * params.candleWidth, params.chartHeight),
      Paint()
      ..strokeWidth = max(params.candleWidth * 0.88, 1.0)
      ..color = params.style.selectionHighlightColor);
    canvas.restore();
    // Draw info pane
    _drawTapInfoOverlay(canvas, params, candle);
  }

  void _drawTapInfoOverlay(canvas, PainterParams params, CandleData candle) {
    final xGap = 8.0;
    final yGap = 4.0;

    TextPainter makeTP(String text) => TextPainter(
      text: TextSpan(
        text: text,
        style: params.style.overlayTextStyle,
      ),
    )
    ..textDirection = TextDirection.ltr
    ..layout();

    final info = getOverlayInfo(candle);
    if (info.isEmpty) return;
    final labels = info.keys.map((text) => makeTP(text)).toList();
    final values = info.values.map((text) => makeTP(text)).toList();

    final labelsMaxWidth = labels.map((tp) => tp.width).reduce(max);
    final valuesMaxWidth = values.map((tp) => tp.width).reduce(max);
    final panelWidth = labelsMaxWidth + valuesMaxWidth + xGap * 3;
    final panelHeight = max(
      labels.map((tp) => tp.height).reduce((a, b) => a + b),
      values.map((tp) => tp.height).reduce((a, b) => a + b),
    ) +
    yGap * (values.length + 1);

    // Shift the canvas, so the overlay panel can appear near touch position.
    canvas.save();
    final pos = params.tapPosition!;
    final fingerSize = 32.0; // leave some margin around user's finger
    double dx, dy;
    assert(params.size.width >= panelWidth, "Overlay panel is too wide.");
    if (pos.dx <= params.size.width / 2) {
      // If user touches the left-half of the screen,
      // we show the overlay panel near finger touch position, on the right.
      dx = pos.dx + fingerSize;
    } else {
      // Otherwise we show panel on the left of the finger touch position.
      dx = pos.dx - panelWidth - fingerSize;
    }
    dx = dx.clamp(0, params.size.width - panelWidth);
    dy = pos.dy - panelHeight - fingerSize;
    if (dy < 0) dy = 0.0;
    canvas.translate(dx, dy);

    // Draw the background for overlay panel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & Size(panelWidth, panelHeight),
        Radius.circular(8),
      ),
      Paint()..color = params.style.overlayBackgroundColor);

    // Draw texts
    var y = 0.0;
    for (int i = 0; i < labels.length; i++) {
      y += yGap;
      final rowHeight = max(labels[i].height, values[i].height);
      // Draw labels (left align, vertical center)
      final labelY = y + (rowHeight - labels[i].height) / 2; // vertical center
      labels[i].paint(canvas, Offset(xGap, labelY));

      // Draw values (right align, vertical center)
      final leading = valuesMaxWidth - values[i].width; // right align
      final valueY = y + (rowHeight - values[i].height) / 2; // vertical center
      values[i].paint(
        canvas,
        Offset(labelsMaxWidth + xGap * 2 + leading, valueY),
      );
      y += rowHeight;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) =>
  params.shouldRepaint(oldDelegate.params);
}

extension ElementAtOrNull<E> on List<E> {
  E? at(int index) {
    if (index < 0 || index >= length) return null;
    return elementAt(index);
  }
}
