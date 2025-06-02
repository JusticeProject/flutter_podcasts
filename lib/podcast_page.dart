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
            children: [
              Container(margin: EdgeInsets.all(10), child: podcast.albumArt),
              // TODO: show title and summary, should some of it overlap with the albumArt using a Stack()?
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

