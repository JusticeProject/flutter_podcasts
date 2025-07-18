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
  bool newEpisodesOnLastRefresh = false;
  int numEpisodesOnDisk = 0;
  int numEpisodesDownloading = 0;
  bool isPlaying = false;

  final List<Episode> episodes;
}

//*************************************************************************************************

class Episode
{
  Episode({
    required this.localDir,
    required this.filename, 
    required this.guid,
    required this.url,
    required this.title, 
    required this.description, 
    required this.descriptionNoHtml,
    required this.albumArt,
    required this.datePublishedUTC});

  final String localDir; 
  String filename; // if filename isNotEmpty then it has been downloaded
  final String guid;
  final String url;
  bool isDownloading = false;
  double downloadProgress = 0.0; // ranges from 0.0 to 1.0

  bool isPlaying = false;
  bool played = false;
  Duration playbackPosition = Duration();
  Duration? playLength;

  final String title;
  final String description;
  final String descriptionNoHtml;
  final Image albumArt;
  final DateTime datePublishedUTC;
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
