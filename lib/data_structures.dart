import 'package:flutter/material.dart';

//*************************************************************************************************

class Feed
{
  Feed(this.localDir, this.title, this.author, this.description, this.albumArt, this.episodes);
  
  final String localDir;
  // TODO: add url for the feed
  final String title;
  final String author;
  final String description;
  final Image albumArt;
  int numEpisodesDownloaded = 0;

  // TODO: add Episodes from the feed and Episodes that have been downloaded
  final List<Episode> episodes;
}

//*************************************************************************************************

class Episode
{
  Episode({required this.localPath, 
    required this.title, 
    required this.description, 
    required this.descriptionNoHtml,
    required this.date});

  final String localPath;
  final String title;
  final String description;
  final String descriptionNoHtml;
  final DateTime date;
}
