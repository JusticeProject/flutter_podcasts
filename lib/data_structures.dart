import 'package:flutter/material.dart';
import 'package:flutter_podcasts/utilities.dart';

//*************************************************************************************************

class Feed
{
  Feed(this.feedNumber, this.localDir, this.title, this.author, this.description, this.albumArt, 
    this.datePublishedUTC, this.episodes);
  
  final int feedNumber;
  final String localDir;

  final String title;
  final String author;
  final String description;
  final Image albumArt;

  final DateTime datePublishedUTC;
  int numEpisodesDownloaded = 0;

  // TODO: add Episodes from the feed and Episodes that have been downloaded
  final List<Episode> episodes;
}

//*************************************************************************************************

class FeedConfig
{
  FeedConfig(this.url, this.datePublishedUTC);
  
  final String url;
  DateTime datePublishedUTC; // date inside the last XML that was downloaded and saved

  @override
  String toString() {
    final String dateStringUTC = dateTimeUTCToStringUTC(datePublishedUTC);
    return "$url\n$dateStringUTC";
  }

  factory FeedConfig.fromExisting(String data)
  {
    List<String> dataSplit = data.split("\n");
    DateTime date = stringToDateTimeUTC(dataSplit[1]);
    FeedConfig config = FeedConfig(dataSplit[0], date);
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
    required this.datePublishedUTC});

  final String localPath;
  final String title;
  final String description;
  final String descriptionNoHtml;
  final DateTime datePublishedUTC;
}
