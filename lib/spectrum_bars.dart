import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class SpectrumBars extends StatefulWidget
{
  const SpectrumBars({super.key});

  @override
  State<SpectrumBars> createState() => _SpectrumBarsState();
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class _SpectrumBarsState extends State<SpectrumBars>
{
  late double _progress;
  late Timer _timer;

  //*******************************************************

  @override
  void initState() {
    //logDebugMsg("SpectrumBars init");
    _progress = 0.0;
    _timer = Timer.periodic(Duration(milliseconds: 30), _onTimerTick);
    super.initState();
  }

  //*******************************************************

  @override
  void dispose() {
    //logDebugMsg("SpectrumBars dispose");
    _timer.cancel();
    super.dispose();
  }

  //*******************************************************

  void _onTimerTick(Timer timer)
  {
    double newProgress = _progress + 0.08;
    if (newProgress > 2 * math.pi)
    {
      newProgress -= 2 * math.pi;
    }

    setState(() {
      _progress = newProgress;
    });
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = colorScheme.inversePrimary;
    final foregroundColor = colorScheme.primary;

    return CustomPaint(
      painter: SpectrumBarsPainter(_progress, backgroundColor, foregroundColor),
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class SpectrumBarsPainter extends CustomPainter
{
  SpectrumBarsPainter(this.progress, this.backgroundColor, this.foregroundColor);
  
  final double progress;
  final Color backgroundColor;
  final Color foregroundColor;

  //*******************************************************
  
  @override
  void paint(Canvas canvas, Size size)
  {
    final backgroundPaint = Paint()..color = backgroundColor;
    final foregroundPaint = Paint()..color = foregroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    double bassHeight = size.height * math.sin(progress).abs();
    //bassHeight = math.min(0.7 * size.height, bassHeight);
    double midHeight = size.height * math.sin(progress + math.pi/3).abs();
    //midHeight = math.min(0.7 * size.height, midHeight);
    double trebleHeight = size.height * math.sin(progress - math.pi/3).abs();
    //trebleHeight = math.min(0.7 * size.height, trebleHeight);
    double barWidth = size.width / 3;
    canvas.drawRect(Rect.fromPoints(Offset(0, size.height), Offset(barWidth, bassHeight)), foregroundPaint);
    canvas.drawRect(Rect.fromPoints(Offset(barWidth, size.height), Offset(2 * barWidth, midHeight)), foregroundPaint);
    canvas.drawRect(Rect.fromPoints(Offset(2 * barWidth, size.height), Offset(size.width, trebleHeight)), foregroundPaint);
  }

  //*******************************************************

  @override
  bool shouldRepaint(SpectrumBarsPainter oldDelegate)
  {
    return progress != oldDelegate.progress;
  }
}
