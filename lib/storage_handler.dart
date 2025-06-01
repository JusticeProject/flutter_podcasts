import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import 'podcast.dart';
import 'utilities.dart';

//*************************************************************************************************

class StorageHandler
{
  int _highestPodcastNumber = -1;

  // Private constructor:
  StorageHandler._privateConstructor();
  // the singleton instance of this class:
  static final StorageHandler _instance = StorageHandler._privateConstructor();
  // factory that always produces the same singleton instance:
  factory StorageHandler() {return _instance;}

  Future<String> getLocalPath() async
  {
    //final directory = await getApplicationDocumentsDirectory();
    //logDebugMsg(directory.path);
    // return directory.path;

    // TODO: android.permission.READ_EXTERNAL_STORAGE ?? if windows use this func but if android use which?
    var dir1 = await getApplicationCacheDirectory();
    //logDebugMsg(dir1.path);
    return dir1.path;

    //var dir2 = await getApplicationSupportDirectory();
    //print(dir2.path);
    //var dir3 = await getExternalStorageDirectory();
    //print(dir3?.path);
    //var dir4 = await getExternalStorageDirectories();
    //print(dir4);
    //var dir5 = await getExternalCacheDirectories();
    //print(dir5);
  }

  //*********************************************

  Future<Podcast> addPodcast(String url) async
  {
    try
    {
      _highestPodcastNumber++;
      String localDir = await getLocalPath();
      localDir += "${Platform.pathSeparator}$_highestPodcastNumber${Platform.pathSeparator}";

      Uint8List rssBytes = await fetchRSS(url);
      String xmlFilename = "${localDir}feed.xml";
      await saveToFile(xmlFilename, rssBytes);
      
      String text = await readFile(xmlFilename);
      XmlDocument xml = XmlDocument.parse(text);

      String imgURL = getImgURLFromXML(xml);
      Uint8List imgBytes = await fetchAlbumArt(imgURL);
      String imgFilename = "${localDir}albumArt.jpg";
      await saveToFile(imgFilename, imgBytes);

      String title = getPodcastTitle(xml);
      logDebugMsg("found title $title");
      return Podcast(localDir, title, Image.file(File(imgFilename)));
    }
    catch (err)
    {
      // TODO: cleanup any folders/files that were created
      _highestPodcastNumber--;
      rethrow;
    }
  }

  //*********************************************

  Future<void> removePodcast(Podcast podcast) async
  {
    // TODO: what if the files are in use? what if the .mp3 is playing right now? I should stop (all?) playback first
    // maybe during loading I could remove files/folders that are marked for deletion
    // or run some background task that periodically tries to remove them
    // what if folder 10 is the highest numbered folder and it's marked for removal but then user wants to add a podcast at the end of the list?

    try
    {
      await Directory(podcast.localDir).delete(recursive: true);
    }
    catch (err)
    {
      logDebugMsg("Exception in removePodcast: ${err.toString()}");
    }
  }

  //*********************************************

  Future<void> saveToFile(String filename, Uint8List bytes) async
  {
    File fd = await File(filename).create(recursive: true);
    await fd.writeAsBytes(bytes);
  }

  //*********************************************

  Future<String> readFile(String filename) async
  {
    File fd = File(filename);
    return await fd.readAsString();
  }

  //*********************************************

  String getImgURLFromXML(XmlDocument xml)
  {
    var elements = xml.findAllElements("image");
    if (elements.isNotEmpty)
    {
      var urls = elements.first.findElements("url");
      if (urls.isNotEmpty)
      {
        return urls.first.innerText;
      }
    }

    elements = xml.findAllElements("itunes:image");
    if (elements.isNotEmpty)
    {
      var first = elements.first;
      if (first.attributes.isNotEmpty)
      {
        return first.attributes.first.value;
      }
    }

    throw Exception("could not find image url in xml");
  }

  //*********************************************

  String getPodcastTitle(XmlDocument xml)
  {
    var elements = xml.findAllElements("title");
    if (elements.isNotEmpty)
    {
      return elements.first.innerText;
    }

    throw Exception("could not find title in xml");
  }

  //*********************************************

  Future<Uint8List> fetchRSS(String url) async
  {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode ~/ 100 != 2)
    {
      throw Exception("Error when fetching RSS at $url: ${resp.statusCode}");
    }
    return resp.bodyBytes;
  }

  //*********************************************

  Future<Uint8List> fetchAlbumArt(String url) async
  {
    final resp = await http.get(Uri.parse(url));
    return resp.bodyBytes;
  }

  //*********************************************

  Future<List<Podcast>> loadPodcasts() async
  {
    var path = await getLocalPath();
    var dir = Directory(path);
    var itemStream = dir.list();

    List<Podcast> podcastList = [];
    await for (var item in itemStream)
    {
      if (item is Directory)
      {
        String xmlFilename = "${item.path}${Platform.pathSeparator}feed.xml";
        String text = await readFile(xmlFilename);
        XmlDocument xml = XmlDocument.parse(text);
        String title = getPodcastTitle(xml);
        String albumArtPath = "${item.path}${Platform.pathSeparator}albumArt.jpg";
        podcastList.add(Podcast(item.path, title, Image.file(File(albumArtPath))));
      }
    }

    podcastList.sort((a, b) {
      // - if less
      // 0 if equal
      // + if greater
      if (a.localDir.length > b.localDir.length)
      {
        return 1;
      }
      else if (a.localDir.length < b.localDir.length)
      {
        return -1;
      }
      else 
      {
        return a.localDir.compareTo(b.localDir);
      }
    });

    if (podcastList.isNotEmpty)
    {
      String folder = podcastList.last.localDir.split(Platform.pathSeparator).last;
      _highestPodcastNumber = int.parse(folder);
    }

    logDebugMsg("_highestPodcastNumber = $_highestPodcastNumber");

    // for testing the circular progress indicator
    //await Future.delayed(Duration(seconds: 5));
    return podcastList;
  }

}
