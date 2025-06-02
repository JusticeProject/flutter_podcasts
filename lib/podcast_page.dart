import 'package:flutter/material.dart';
import 'podcast.dart';

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
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
              const Divider(),
              const Text("Episode"),
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
