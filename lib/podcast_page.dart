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
              // TODO: make the description/summary collapsable
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
                child: Text(podcast.description, textAlign: TextAlign.center),
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

