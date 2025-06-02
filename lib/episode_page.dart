import 'package:flutter/material.dart';
import 'podcast.dart';

//*************************************************************************************************

class EpisodePage extends StatelessWidget
{
  const EpisodePage({super.key, required this.episode});

  final Episode episode;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(episode.title, style: Theme.of(context).textTheme.headlineLarge),
              Text(episode.description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
