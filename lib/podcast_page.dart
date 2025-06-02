import 'package:flutter/material.dart';
import 'utilities.dart';
import 'podcast.dart';
import 'episode_page.dart';

//*************************************************************************************************

class PodcastPage extends StatelessWidget
{
  const PodcastPage({super.key, required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context) {
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
              Container(margin: EdgeInsets.fromLTRB(180, 10, 180, 10), child: podcast.albumArt),
              Text(podcast.title, style: Theme.of(context).textTheme.headlineMedium),
              Text(podcast.author, style: Theme.of(context).textTheme.labelMedium),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
                child: CollapsibleText(text: podcast.description),
              ),
              for (var episode in podcast.episodes)
                GestureDetector(
                  onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EpisodePage(episode: episode))),
                  child:
                    EpisodePreview(episode: episode)
                ),
                // TODO: use a builder for a ListView?
                // TODO: when EpisodePreview widget is tapped need to navigate to EpisodeDetailPage
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

  void _onDownloadEpisode()
  {
    // TODO:
    logDebugMsg("downloading ${episode.title}");
  }

  void _onPlayEpisode()
  {
    // TODO:
    logDebugMsg("playing ${episode.title}");
  }

  @override
  Widget build(BuildContext context) {
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
            Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(episode.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text("unplayed"),
                Expanded(child: SizedBox()),
                IconButton(
                  onPressed: _onDownloadEpisode,
                  icon: Icon(Icons.download)
                ),
                IconButton(
                  onPressed: _onPlayEpisode, 
                  icon: Icon(Icons.play_arrow))
              ]
            )
          ],
        ),
      ),
    );
  }
}
