import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'utilities.dart';
import 'data_structures.dart';
import 'data_model.dart';
import 'common_widgets.dart';

//*************************************************************************************************

class EpisodePage extends StatelessWidget
{
  const EpisodePage({super.key, required this.episode});

  final Episode episode;

  //*******************************************************

  // another audio package, doesn't work on Windows
  // https://pub.dev/packages/just_audio

  // TODO: audio only, no video, how do I handle it if user enters rss feed that only has videos?

  // TODO: audio player shows on lockscreen, stops playing when headphones removed, try this package
  // https://pub.dev/packages/audio_service

  // When the user taps a link in the Episode description
  void _onLinkTapped(String? url) async
  {
    if (url != null)
    {
      logDebugMsg(url);

      try
      {
        final Uri uri = Uri.parse(url);
        bool canLaunch = await canLaunchUrl(uri);
        if (canLaunch)
        {
          logDebugMsg("can launch");
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
        else
        {
          logDebugMsg("can't launch");
        }
      }
      catch (err)
      {
        logDebugMsg("caught exception: ${err.toString()}");
      }
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(margin: EdgeInsets.fromLTRB(130, 0, 130, 10), child: episode.albumArt),
                Text(episode.title, style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 100, height: 100, child: DownloadButton(episode: episode, largeIcon: true)),
                    SizedBox(width: 100, height: 100, child: PlayButton(episode: episode, largeIcon: true, usePrimaryColor: true))
                  ],
                ),
                SizedBox(height: 10),
                AudioProgressBar(episode: episode),
                SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 100, height: 100, child: RewindButton(episode: episode)),
                    SizedBox(width: 100, height: 100, child: FastForwardButton(episode: episode))
                ]),
                Html(data: episode.description, onLinkTap: (url, attributes, element) => _onLinkTapped(url))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class AudioProgressBar extends StatefulWidget
{
  const AudioProgressBar({super.key, required this.episode});

  final Episode episode;

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

//*************************************************************************************************

class _AudioProgressBarState extends State<AudioProgressBar>
{
  late double _sliderPosition;
  late bool _scrubbing;

  //*******************************************************

  @override
  void initState()
  {
    _sliderPosition = 0.0;
    _scrubbing = false;
    super.initState();
  }

  //*******************************************************

  void _onChanged(double userFingerPosition)
  {
    //logDebugMsg("onChanged: $userFingerPosition");
    setState(() {
      _sliderPosition = userFingerPosition;
    });
  }

  //*******************************************************

  void _onChangeStart(double userFingerPosition)
  {
    //logDebugMsg("onChangeStart");
    _scrubbing = true;
  }

  //*******************************************************

  void _onChangeEnd(double userFingerPosition, DataModel dataModel) async
  {
    //logDebugMsg("onChangeEnd");
    _scrubbing = false;

    // first convert the slider to a usable timestamp
    Duration desiredPosition = sliderValueToDuration(userFingerPosition, widget.episode.playLength);

    // make sure we don't go past the end of the file, we'll go up to 500ms before the end
    int lengthMilliseconds = widget.episode.playLength?.inMilliseconds ?? 0;
    int newMilliseconds = math.min(desiredPosition.inMilliseconds, lengthMilliseconds - 500);

    try
    {
      await dataModel.seekEpisode(widget.episode, Duration(milliseconds: newMilliseconds));
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  double durationToSliderValue(Duration playbackPosition, Duration? playLength)
  {
    if (playLength == null)
    {
      return 0.0;
    }

    double calculatedSliderValue = playbackPosition.inSeconds.toDouble() / playLength.inSeconds.toDouble();
    return calculatedSliderValue > 1.0 ? 1.0 : calculatedSliderValue;
  }

  //*******************************************************

  Duration sliderValueToDuration(double sliderValue, Duration? playLength)
  {
    if (playLength == null)
    {
      return Duration(); 
    }

    double seconds = sliderValue * playLength.inSeconds;
    return Duration(seconds: seconds.toInt());
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    DataModel dataModel = context.watch<DataModel>();
    final colorScheme = Theme.of(context).colorScheme;
    if (!widget.episode.isPlaying)
    {
      // If you are scrubbing while the episode ends then restarting the episode doesn't work right. 
      // onChangedEnd won't get called so it thinks it is still scrubbing.
      _scrubbing = false;
    }
    
    return Column(
      children: [
        Slider(
          activeColor: colorScheme.primary,
          secondaryActiveColor: Colors.white,
          secondaryTrackValue: 1.0,
          min: 0.0, 
          max: 1.0, 
          // If the user is currently scrubbing (moving it with their finger) then we use the person's finger to set the current position.
          // If the user is not scrubbing we use the audio player's current position.
          value: _scrubbing ? _sliderPosition : durationToSliderValue(widget.episode.playbackPosition, widget.episode.playLength), 
          // If the episode is playing we enable the slider by providing callbacks. If the episode is not playing we disable the slider
          // by passing in null for all the callbacks.
          onChanged: widget.episode.isPlaying ? _onChanged : null, 
          onChangeStart: widget.episode.isPlaying ? _onChangeStart : null, 
          onChangeEnd: widget.episode.isPlaying ? (newValue) => _onChangeEnd(newValue, dataModel) : null
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(playbackDurationPrettyPrint(
              _scrubbing ? sliderValueToDuration(_sliderPosition, widget.episode.playLength) : widget.episode.playbackPosition, 
              null, true)
            ),
            Text(playbackDurationPrettyPrint(
              widget.episode.playLength, 
              _scrubbing ? sliderValueToDuration(_sliderPosition, widget.episode.playLength) : widget.episode.playbackPosition, true)
            )
          ]
        )
      ],
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

String playbackDurationPrettyPrint(Duration? dur, Duration? toSubtract, bool includeSeconds)
{
  if (dur == null)
  {
    return "";
  }

  // first copy to a new one so we don't change the real one, use microseconds so we don't truncate anything
  Duration actualDur = Duration(microseconds: dur.inMicroseconds);
  if (toSubtract != null)
  {
    actualDur = actualDur - toSubtract;
  }

  int hours = actualDur.inHours;
  int minutes = actualDur.inMinutes - hours * 60;

  if (includeSeconds)
  {
    // example: 1:45:01
    int seconds = actualDur.inSeconds - hours * 3600 - minutes * 60;
    return "${hours.toString()}:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}";
  }
  else
  {
    // example: 1 hr 45 mins left
    if (hours > 0)
    {
      return ("$hours hr${hours == 1 ? "" : "s"} $minutes min${minutes == 1 ? "" : "s"} left");
    }
    else
    {
      return ("$minutes min${minutes == 1 ? "" : "s"} left");
    }
  }
}
