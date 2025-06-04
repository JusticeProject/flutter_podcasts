import 'package:flutter/material.dart';

//*************************************************************************************************

class Feed
{
  Feed(this.feedNumber, this.localDir, this.title, this.author, this.description, this.albumArt, this.episodes);
  
  final int feedNumber;
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

class FeedConfig
{
  FeedConfig(this.url, this.pubDate);
  
  final String url;
  String pubDate; // date inside the last XML that was downloaded and saved

  @override
  String toString() {
    return "$url\n$pubDate";
  }

  factory FeedConfig.fromExisting(String data)
  {
    List<String> dataSplit = data.split("\n");
    FeedConfig config = FeedConfig(dataSplit[0], dataSplit[1]);
    return config;
  }
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
