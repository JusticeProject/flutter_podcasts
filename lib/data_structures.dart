import 'package:flutter/material.dart';

//*************************************************************************************************

class Podcast
{
  Podcast(this.localDir, this.title, this.author, this.description, this.albumArt, this.episodes);
  
  final String localDir;
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
  Episode({required this.localPath, required this.title, required this.description, required this.descriptionNoHtml});

  final String localPath;
  final String title;
  final String description;
  final String descriptionNoHtml;
}
