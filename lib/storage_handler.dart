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

  Future<String> getLocalPath() async
  {
    //final directory = await getApplicationDocumentsDirectory();
    //logDebugMsg(directory.path);
    // return directory.path;

    // TODO: android.permission.READ_EXTERNAL_STORAGE ?? also need to figure out which one to use
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
