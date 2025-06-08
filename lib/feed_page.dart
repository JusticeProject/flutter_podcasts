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
                // TODO: use a builder for a ListView?
            ],
          ),
        ),
      ),
    );
  }
}

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
                // TODO: if the date says 1 hour ago then wait 10 hours... it will still say 1 hour ago
                // Future.periodic in the Constructor? or initState (StatefulWidget)? cancel it in onDispose, use logDebugMsg to make sure 
                // it gets called. Wrap with setState. String _prettyPrintDate member variable.
                // Or just have the user refresh all feeds? But it may not show the updated time if there were no new xml files saved.
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
                DownloadButton(episode: episode),
                PlayButton(episode: episode)
              ]
            )
          ],
        ),
      ),
    );
  }
}

//*************************************************************************************************

class DownloadButton extends StatelessWidget
{
  const DownloadButton({super.key, required this.episode});

  final Episode episode;

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
      // show disabled download button until we have some progress to show
      return IconButton(
        icon: Icon(Icons.download, color: Theme.of(context).disabledColor),
        onPressed: () {},
      );
    }
    else if (episode.isDownloading && episode.downloadProgress > 0)
    {
      // Wrap the indicator with a GestureDetector so we can disable tapping on it
      return GestureDetector(
        onTap: () {},
        // CircularProgressIndicator can take a value from 0 to 1 to show the download progress
        child: CircularProgressIndicator(value: episode.downloadProgress));
    }
    else if (episode.filename.isEmpty)
    {
      // enable download button
      return IconButton(
        icon: Icon(Icons.download),
        onPressed: () => _onDownloadEpisode(dataModel)
      );
    }
    else
    {
      // show download complete button, can be tapped to remove the download
      return IconButton(
        icon: Icon(Icons.download_done, color: Theme.of(context).colorScheme.primary),
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

class PlayButton extends StatelessWidget
{
  const PlayButton({super.key, required this.episode});

  final Episode episode;

  //*******************************************************

  void _onPlayEpisode(DataModel dataModel) async
  {
    logDebugMsg("playing ${episode.title}");
    try
    {
      await dataModel.playEpisode(episode);
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
        onPressed: () {}
      );
    }
    else if (episode.isPlaying)
    {
      // it's playing
      return IconButton(
        icon: Icon(Icons.pause),
        onPressed: () => _onPauseEpisode(dataModel),
      );
    }
    else
    {
      // we have the file downloaded but it's not playing right now
      return IconButton(
        icon: Icon(Icons.play_arrow),
        onPressed: () => _onPlayEpisode(dataModel)
      );
    }
  }
}
