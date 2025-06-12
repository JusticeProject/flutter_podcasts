import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data_model.dart';
import 'utilities.dart';
import 'data_structures.dart';
import 'episode_page.dart';
import 'spectrum_bars.dart';
import 'common_widgets.dart';

//*************************************************************************************************

class FeedPage extends StatelessWidget
{
  const FeedPage({super.key, required this.feed});

  final Feed feed;

  @override
  Widget build(BuildContext context)
  {
    return SafeArea(
      child: Scaffold(
        // TODO: how can I make the AppBar disappear when I scroll down the page?
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 80), // leave some space at the bottom in case the MiniPlayer is visible
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
    // TODO: check all Consumer<DataModel> and
    // DataModel dataModel = Provider.of<DataModel>(context, listen: false); and
    // context.watch<DataModel>();
    // to make sure they are needed. Move them to child Widgets if possible - we don't want to rebuild large portions
    // of the UI if we don't have to.

    return Container(
      padding: EdgeInsets.fromLTRB(15, 0, 15, 0),
      //height: 150,
      // the Card is necessary so when the user taps an area that doesn't have text it still navigates to the EpisodePage
      child: Card(
        margin: EdgeInsets.all(0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(episode.descriptionNoHtml, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: Colors.grey)),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // If the date says 1 hour ago then wait 10 hours... it will still say 1 hour ago. That's ok, it will update
                // when the user refreshes or the app/FeedPage reloads.
                Text(dateTimeUTCToPrettyPrint(episode.datePublishedUTC)),
                SizedBox(width: 6),
                Icon(Icons.circle, size: 5),
                SizedBox(width: 6),
                EpisodeStatus(episode: episode), // played vs unplayed vs how much time left
                Spacer(),
                FittedBox(
                  child: Consumer<DataModel>(builder: (context, value, child) {
                    if (episode.isPlaying)
                    {
                      return SizedBox(width: 30, height: 20, child: SpectrumBars());
                    }
                    else
                    {
                      return SizedBox.shrink();
                    }
                  })
                ),
                SizedBox(width: 12),
                DownloadButton(episode: episode, largeIcon: false),
                PlayButton(episode: episode, largeIcon: false, usePrimaryColor: true)
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

class EpisodeStatus extends StatelessWidget
{
  const EpisodeStatus({super.key, required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context)
  {
    context.watch<DataModel>();

    if (episode.playbackPosition.inSeconds > 0 && episode.playLength != null)
    {
      String result = playbackDurationPrettyPrint(episode.playLength, episode.playbackPosition, false);
      return Text(result);
    }
    else if (episode.played)
    {
      return const Text("Played", style: TextStyle(color: Colors.red));
    }
    else
    {
      // need to keep it as unplayed until the first time we play the file and AudioPlayer gives us the length, 
      // the XML file won't be reliable for giving us the length because the CDN can insert ads of different lengths
      return const Text("Unplayed");
    }
  }
}
