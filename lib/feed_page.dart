import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data_model.dart';
import 'utilities.dart';
import 'data_structures.dart';
import 'episode_page.dart';
import 'spectrum_bars.dart';

//*************************************************************************************************

class FeedPage extends StatelessWidget
{
  const FeedPage({super.key, required this.feed});

  final Feed feed;

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      // TODO: how can I make the AppBar disappear when I scroll down the page?
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(margin: EdgeInsets.fromLTRB(100, 10, 100, 10), child: feed.albumArt),
              Text(feed.title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              Text(feed.author, style: Theme.of(context).textTheme.labelMedium),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
                child: CollapsibleText(text: feed.description),
              ),
              for (var episode in feed.episodes)
                GestureDetector(
                  onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EpisodePage(episode: episode))),
                  child:
                    EpisodePreview(episode: episode)
                ),
                // TODO: use a builder for a ListView? If I allow more than 10 episodes per Feed then I should consider this
            ],
          ),
        ),
      ),
      bottomSheet: Consumer<DataModel>(
        builder: (context, dataModel, child) {
          if (dataModel.currentEpisode != null)
          {
            return MiniPlayer(episode: dataModel.currentEpisode!);
          }
          else
          {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class CollapsibleText extends StatefulWidget
{
  final String text;

  const CollapsibleText({super.key, required this.text});

  @override
  State<CollapsibleText> createState() => _CollapsibleTextState();
}

//*************************************************************************************************

class _CollapsibleTextState extends State<CollapsibleText>
{
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(widget.text, maxLines: _isExpanded ? null : 2, overflow: TextOverflow.fade, softWrap: true, textAlign: TextAlign.center),
          if (!_isExpanded)
            const Text('...More', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_isExpanded)
            Center(child: const IconButton(onPressed: null, icon: Icon(Icons.arrow_drop_up)))
        ],
      ),
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class EpisodePreview extends StatelessWidget
{
  const EpisodePreview({super.key, required this.episode});

  final Episode episode;

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    //DataModel dataModel = Provider.of<DataModel>(context, listen: false);
    context.watch<DataModel>();

    return Container(
      padding: EdgeInsets.fromLTRB(15, 0, 15, 0),
      height: 150,
      // the Card is necessary so when the user taps an area that doesn't have text it still navigates to the EpisodePage
      child: Card(
        margin: EdgeInsets.all(0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(episode.descriptionNoHtml, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey)),
            // TODO: 3 dots icon on right side which shows bottom sheet: Mark as Played/Unplayed, no download
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // If the date says 1 hour ago then wait 10 hours... it will still say 1 hour ago. That's ok, it will update
                // when the user refreshes or the app/FeedPage reloads.
                Text(dateTimeUTCToPrettyPrint(episode.datePublishedUTC)),
                SizedBox(width: 8),
                Icon(Icons.circle, size: 5),
                SizedBox(width: 8),
                const Text("unplayed"), 
                // TODO: played vs 40 min vs 38 min left + progress bar, may have to keep it as unplayed until the first time we
                // play the file and AudioPlayer gives us the length, the XML file won't be reliable for giving us the length because
                // the CDN can insert ads of different lengths
                SizedBox(width: 8),
                if (episode.isPlaying)
                  FittedBox(child: SizedBox(width: 30, height: 20, child: SpectrumBars())),
                Spacer(),
                DownloadButton(episode: episode, largeIcon: false),
                PlayButton(episode: episode, largeIcon: false)
              ]
            )
          ],
        ),
      ),
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
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
        icon: CircularProgressIndicator(value: episode.downloadProgress),
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
  const PlayButton({super.key, required this.episode, required this.largeIcon});

  final Episode episode;
  final bool largeIcon;

  //*******************************************************

  void _onPlayEpisode(DataModel dataModel) async
  {
    try
    {
      await dataModel.playEpisode(episode);
      // TODO: when should the bottom sheet be hidden? does it handle episode completion? what if that episode
      // has been removed? what about when a SnackBar is shown due to showMessageToUser?
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
        icon: Icon(Icons.pause),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onPauseEpisode(dataModel),
      );
    }
    else
    {
      // we have the file downloaded but it's not playing right now
      return IconButton(
        icon: Icon(Icons.play_arrow),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onPlayEpisode(dataModel)
      );
    }
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class MiniPlayer extends StatelessWidget
{
  const MiniPlayer({super.key, required this.episode});

  final Episode episode;

  // TODO: show albumArt on left side of MiniPlayer? would need to get the Feed object, or put a reference to
  // the albumArt in the Episode class? then put albumArt on EpisodePage too?

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
          children: [
            Expanded(child: 
              Text(episode.title, maxLines: 2, overflow: TextOverflow.fade, style: TextStyle(fontWeight: FontWeight.bold))
            ),
            PlayButton(episode: episode, largeIcon: false)
        ]),
      ),
    );
  }
}
