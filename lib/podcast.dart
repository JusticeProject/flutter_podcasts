import 'package:flutter/material.dart';

//*************************************************************************************************

class Podcast
{
  Podcast(this.localDir, this.title, this.albumArt);
  
  final String localDir;
  final String title;
  final Image albumArt;
  int numEpisodesDownloaded = 0;

  // TODO: add Episodes from the feed and Episodes that have been downloaded
}

//*************************************************************************************************

class Episode
{
  Episode({required this.localPath});

  final String localPath;
}
