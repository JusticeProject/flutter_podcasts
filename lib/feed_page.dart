import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data_model.dart';
import 'utilities.dart';
import 'data_structures.dart';
import 'episode_page.dart';

//*************************************************************************************************

class FeedPage extends StatelessWidget
{
  const FeedPage({super.key, required this.feed});

  final Feed feed;

  // TODO: Refresh, drag down on FeedPage?
  // can query the DataModel for the updated Feed, pass an id/index/feed url to the DataModel so it knows which one?

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
              Text(feed.title, style: Theme.of(context).textTheme.headlineMedium),
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

  void _onDownloadEpisode(DataModel dataModel) async
  {
    // TODO: implement downloading (or removing if already downloaded)
    // is there a download icon combined with progress indicator?
    // pause/cancel downloading? or prevent user from pressing while dataModel.isDownloading/isBusy?
    // what if multiple files are being downloaded at once?
    logDebugMsg("download requested for ${episode.title}");
    await dataModel.fetchEpisode(episode);
  }

  void _onPlayEpisode()
  {
    // TODO: implement playing / pausing episode
    logDebugMsg("playing ${episode.title}");
  }

  @override
  Widget build(BuildContext context)
  {
    //DataModel dataModel = Provider.of<DataModel>(context, listen: false);
    DataModel dataModel = context.watch<DataModel>();

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
            // TODO: 3 dots icon on right side which shows bottom sheet: Mark as Played/Unplayed, Download?
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
                const Text("unplayed"), // TODO: played vs 40 min vs 38 min left + progress bar
                Spacer(),
                IconButton(
                  onPressed: () => _onDownloadEpisode(dataModel),
                  icon: Icon(episode.filename.isEmpty ? Icons.download : Icons.download_done)
                ),
                IconButton(
                  onPressed: _onPlayEpisode, 
                  // TODO: disable the play button until it is downloaded
                  icon: Icon(Icons.play_arrow))
              ]
            )
          ],
        ),
      ),
    );
  }
}
