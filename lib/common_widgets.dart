import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'episode_page.dart';
import 'data_structures.dart';
import 'data_model.dart';
import 'utilities.dart';

//*************************************************************************************************

class DownloadButton extends StatelessWidget
{
  const DownloadButton({super.key, required this.episode, required this.largeIcon});

  final Episode episode;
  final bool largeIcon;

  //*******************************************************

  void _onDownloadEpisode(DataModel dataModel) async
  {
    logDebugMsg("download requested for ${episode.title}");
    try
    {
      await dataModel.fetchEpisode(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  void _onRemoveDownloadedEpisode(DataModel dataModel) async
  {
    logDebugMsg("removing episode ${episode.title}");
    try
    {
      await dataModel.removeEpisode(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    DataModel dataModel = context.watch<DataModel>();

    if (episode.isDownloading && episode.downloadProgress == 0.0)
    {
      // show a grey spinning progress indicator until we have some progress to show
      return IconButton(
        icon: CircularProgressIndicator(color: Theme.of(context).disabledColor),
        iconSize: largeIcon ? 60 : null,
        // I don't like having to specify exact sizes below in the BoxConstraints, but the progress indicator and Icons.download
        // were not the same size, so when it switched between the two the layout shifted up/down
        constraints: largeIcon ? null : BoxConstraints(minWidth: 40, minHeight: 40, maxWidth: 40, maxHeight: 40),
        onPressed: () {},
      );
    }
    else if (episode.isDownloading && episode.downloadProgress > 0)
    {
      // show download progress
      return IconButton(
        icon: CircularProgressIndicator(value: episode.downloadProgress, backgroundColor: Colors.grey),
        iconSize: largeIcon ? 60 : null,
        constraints: largeIcon ? null : BoxConstraints(minWidth: 40, minHeight: 40, maxWidth: 40, maxHeight: 40),
        onPressed: () {}
      );
    }
    else if (episode.filename.isEmpty)
    {
      // enable download button
      return IconButton(
        icon: Icon(Icons.download),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onDownloadEpisode(dataModel)
      );
    }
    else
    {
      // show download complete button, can be tapped to remove the download
      return IconButton(
        icon: Icon(Icons.download_done, color: Theme.of(context).colorScheme.primary),
        iconSize: largeIcon ? 60 : null,
        onPressed: () {
          showDialog(context: context, builder: (context) {
            return AlertDialog(
              title: Text("Remove downloaded episode?"),
              actions: [
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
                TextButton(child: const Text('Remove'), onPressed: () {
                    _onRemoveDownloadedEpisode(dataModel);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
        },
        
      );
    }
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class PlayButton extends StatelessWidget
{
  const PlayButton({super.key, required this.episode, required this.largeIcon, required this.usePrimaryColor});

  final Episode episode;
  final bool largeIcon;
  final bool usePrimaryColor;

  //*******************************************************

  void _onPlayEpisode(DataModel dataModel) async
  {
    try
    {
      await dataModel.playEpisode(episode);
      dataModel.showMiniPlayer(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  void _onPauseEpisode(DataModel dataModel) async
  {
    try
    {
      await dataModel.pauseEpisode(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    DataModel dataModel = context.watch<DataModel>();

    if (episode.filename.isEmpty)
    {
      // no downloaded file and it's obviously not playing right now
      return IconButton(
        icon: Icon(Icons.play_arrow_outlined, color: Theme.of(context).disabledColor),
        iconSize: largeIcon ? 60 : null,
        onPressed: () {}
      );
    }
    else if (episode.isPlaying)
    {
      // it's playing
      return IconButton(
        icon: Icon(Icons.pause, color: usePrimaryColor ? Theme.of(context).colorScheme.primary : null),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onPauseEpisode(dataModel),
      );
    }
    else
    {
      // we have the file downloaded but it's not playing right now
      return IconButton(
        icon: Icon(Icons.play_arrow, color: usePrimaryColor ? Theme.of(context).colorScheme.primary : null),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onPlayEpisode(dataModel)
      );
    }
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class RewindButton extends StatelessWidget
{
  const RewindButton({super.key, required this.episode});

  final Episode episode;

  //*******************************************************

  Future<void> _onSeek(DataModel dataModel) async
  {
    try
    {
      int newSeconds = math.max(episode.playbackPosition.inSeconds - 10, 0);
      await dataModel.seekEpisode(episode, Duration(seconds: newSeconds));
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    DataModel dataModel = context.watch<DataModel>();
    final color = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: episode.isPlaying ? () => _onSeek(dataModel) : null, 
      child: CustomPaint(painter: ArcPainter(forward: false, enabled: episode.isPlaying, color: color))
    );
  }
  
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class FastForwardButton extends StatelessWidget
{
  const FastForwardButton({super.key, required this.episode});

  final Episode episode;

  //*******************************************************

  Future<void> _onSeek(DataModel dataModel) async
  {
    try
    {
      // Don't let the user seek past the end of the file. Stop at 0.5 seconds before the end. This feels more
      // natural: when we want to mark the episode as played we quickly fast forward near the end of the podcast,
      // but we don't want to wait a full second before it stops playing. 
      int lengthMilliseconds = episode.playLength?.inMilliseconds ?? 0;
      int newMilliseconds = math.min(episode.playbackPosition.inMilliseconds + 30000, lengthMilliseconds - 500);
      await dataModel.seekEpisode(episode, Duration(milliseconds: newMilliseconds));
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    DataModel dataModel = context.watch<DataModel>();
    final color = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: episode.isPlaying ? () => _onSeek(dataModel) : null, 
      child: CustomPaint(painter: ArcPainter(forward: true, enabled: episode.isPlaying, color: color))
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class ArcPainter extends CustomPainter
{
  ArcPainter({required this.forward, required this.enabled, required this.color});

  final bool forward;
  final bool enabled;
  final Color color;
  
  @override
  void paint(Canvas canvas, Size size)
  {
    //canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);
    Color disabledColor = Color.fromARGB(255, 109, 109, 109);
    final rect = Rect.fromLTWH(15, 15, size.width-30, size.height-30);
    double startAngle = forward ? 0 : math.pi;
    double sweepAngle = forward ? (3 * math.pi / 2) : (-3 * math.pi / 2);
    final paint = Paint()
      ..color = enabled ? color : disabledColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    
    // Draw the arrow at the end of the arc
    final arrowAngle = forward ? 0 : math.pi;
    const arrowSize = 13.0;
    final arrowX = size.width / 2 + (forward ? 4 : -4);
    final arrowY = 15;

    final arrowPath = Path();
    arrowPath.moveTo(arrowX + arrowSize * math.cos(arrowAngle), arrowY + arrowSize * math.sin(arrowAngle));
    arrowPath.lineTo(arrowX + arrowSize * math.cos(arrowAngle + 2 * math.pi / 3), arrowY + arrowSize * math.sin(arrowAngle + 2 * math.pi / 3));
    arrowPath.lineTo(arrowX + arrowSize * math.cos(arrowAngle - 2 * math.pi / 3), arrowY + arrowSize * math.sin(arrowAngle - 2 * math.pi / 3));
    arrowPath.close();
    canvas.drawPath(arrowPath, paint..style = PaintingStyle.fill);

    // draw the text in the middle
    String text = forward ? "30" : "10";
    final textPainter = 
      TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: enabled ? color : disabledColor, fontSize: 28.0)), 
        textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: size.width);

    final textX = size.width / 2 - textPainter.width / 2;
    final textY = size.height / 2 - textPainter.height / 2;

    textPainter.paint(canvas, Offset(textX, textY));
  }

  @override
  bool shouldRepaint(ArcPainter oldDelegate)
  {
    return enabled != oldDelegate.enabled;
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class MiniPlayer extends StatelessWidget
{
  const MiniPlayer({super.key, required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EpisodePage(episode: episode))),
      child: Container(
        color: Colors.grey[850],
        padding: EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 40, height: 40, child: episode.albumArt),
            SizedBox(width: 10),
            Expanded(child: 
              Text(episode.title, maxLines: 2, overflow: TextOverflow.fade, style: TextStyle(fontWeight: FontWeight.bold))
            ),
            PlayButton(episode: episode, largeIcon: false, usePrimaryColor: false)
        ]),
      ),
    );
  }
}
