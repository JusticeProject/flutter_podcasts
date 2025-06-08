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
    required this.datePublishedUTC});

  final String localDir; 
  String filename; // if filename isNotEmpty then it has been downloaded
  final String guid;
  final String url;
  bool isDownloading = false;

  bool isPlaying = false;
  // TODO: what if file is playing while user refreshes?
  // TODO: need to save the positions/played for each file to disk if the duration is > 0, when loading check to see if the positions file has
  // the guid/filename, save to disk in DataModel's destructor?
  Duration playbackPosition = Duration();

  final String title;
  final String description;
  final String descriptionNoHtml;
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
