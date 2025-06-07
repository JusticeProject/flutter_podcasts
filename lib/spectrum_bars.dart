import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class SpectrumBars extends StatefulWidget
{
  const SpectrumBars({super.key});

  //final Size size;

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
    _timer = Timer.periodic(Duration(milliseconds: 40), _onTimerTick);
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
    double newProgress = _progress + 0.1;
    if (newProgress > 2 * math.pi)
    {
      newProgress = 0;
    }

    setState(() {
      _progress = newProgress;
    });
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    return CustomPaint(
      //size: widget.size,
      painter: SpectrumBarsPainter(_progress),
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class SpectrumBarsPainter extends CustomPainter
{
  SpectrumBarsPainter(this.progress);
  
  final double progress;

  //*******************************************************
  
  @override
  void paint(Canvas canvas, Size size)
  {
    final backgroundPaint = Paint()..color = Colors.black;
    final foregroundPaint = Paint()..color = Colors.white;
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
