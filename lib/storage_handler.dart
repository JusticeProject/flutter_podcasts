import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import 'data_structures.dart';
import 'utilities.dart';

//*************************************************************************************************

class StorageHandler
{
  int _highestFeedNumber = -1;

  // Private constructor:
  StorageHandler._privateConstructor();
  // the singleton instance of this class:
  static final StorageHandler _instance = StorageHandler._privateConstructor();
  // factory that always produces the same singleton instance:
  factory StorageHandler() {return _instance;}

  //*********************************************

  Future<String> getLocalPath() async
  {
    // TODO: android.permission.READ_EXTERNAL_STORAGE ??
    var dir1 = await getApplicationCacheDirectory();
    //logDebugMsg(dir1.path);
    return dir1.path;
  }

  //*********************************************
  //*********************************************
  //*********************************************

  Future<Feed> addFeed(String url) async
  {
    try
    {
      // TODO: save url and date last retrieved in a .txt file, this will be used during refreshFeed
      // saveFeedConfig, loadFeedConfig, class FeedConfig{url, pubDate from last downloaded xml}

      _highestFeedNumber++;
      String localDir = await getLocalPath();
      localDir += "${Platform.pathSeparator}$_highestFeedNumber${Platform.pathSeparator}";

      Uint8List rssBytes = await fetchRSS(url);
      String xmlFilename = "${localDir}feed.xml";
      await saveToFile(xmlFilename, rssBytes);
      
      String text = await readFile(xmlFilename);
      XmlDocument xml = XmlDocument.parse(text);

      String imgURL = getImgURLFromXML(xml);
      Uint8List imgBytes = await fetchAlbumArt(imgURL);
      String imgFilename = "${localDir}albumArt.jpg";
      await saveToFile(imgFilename, imgBytes);

      String title = getFeedTitle(xml);
      String author = getFeedAuthor(xml);
      String description = getFeedDescription(xml);
      logDebugMsg("found title $title");
      List<Episode> episodes = getEpisodes(xml);
      return Feed(localDir, title, author, description, Image.file(File(imgFilename)), episodes);
    }
    catch (err)
    {
      // TODO: cleanup any folders/files that were created
      _highestFeedNumber--;
      rethrow;
    }
  }

  //*********************************************

  Future<void> removeFeed(Feed feed) async
  {
    // TODO: what if the files are in use? what if the .mp3 is playing right now? I should stop (all?) playback first
    // maybe during loading I could remove files/folders that are marked for deletion
    // or run some background task that periodically tries to remove them
    // what if folder 10 is the highest numbered folder and it's marked for removal but then user wants to add a podcast at the end of the list?

    try
    {
      await Directory(feed.localDir).delete(recursive: true);
    }
    catch (err)
    {
      logDebugMsg("Exception in removeFeed: ${err.toString()}");
    }
  }

  //*********************************************

  Future<List<Feed>> loadAllFeedsFromDisk() async
  {
    var path = await getLocalPath();
    var dir = Directory(path);
    var itemStream = dir.list();

    // TODO: need a try/catch here, it may not have been caught in addPodcast because the new xml was downloaded later which is missing info
    // But then I won't be able to display the episodes, should I keep a backup of the old xml file?
    // try/catch is also needed so the app doesn't crash on loading

    // TODO: should I move the below to loadFeedFromDisk?

    List<Feed> feedList = [];
    await for (var item in itemStream)
    {
      if (item is Directory)
      {
        // TODO: move this to a separate function that takes in xml and returns Podcast instance, I don't want to duplicate
        // code here and in addPodcast
        String xmlFilename = "${item.path}${Platform.pathSeparator}feed.xml";
        String text = await readFile(xmlFilename);
        XmlDocument xml = XmlDocument.parse(text);
        String title = getFeedTitle(xml);
        String author = getFeedAuthor(xml);
        String description = getFeedDescription(xml);
        String albumArtPath = "${item.path}${Platform.pathSeparator}albumArt.jpg";
        List<Episode> episodes = getEpisodes(xml);
        feedList.add(
          Feed(item.path, title, author, description, Image.file(File(albumArtPath)), episodes)
        );
      }
    }

    feedList.sort((a, b) {
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

    if (feedList.isNotEmpty)
    {
      String folder = feedList.last.localDir.split(Platform.pathSeparator).last;
      _highestFeedNumber = int.parse(folder);
    }

    logDebugMsg("_highestFeedNumber = $_highestFeedNumber");

    // for testing the circular progress indicator
    //await Future.delayed(Duration(seconds: 5));
    return feedList;
  }

  //*********************************************

  Future<List<Feed>> refreshAllFeeds()
  {
    // TODO: call refreshFeed for each feed

    // the url is in the xml file at 
    // <atom:link href="https://talkpython.fm/episodes/rss" rel="self" type="application/rss+xml"/>
    // or 
    // <link>https://www.npr.org/podcasts/510289/planet-money</link>
    // I don't think I should rely on that

    // TODO: what if I have the 10th episode downloaded then the feed updates so it's now the 11th episode? should I delete the 11th episode?
    // TODO: const MAX_EPISODES = 10? then use it here and in getEpisodes()

    // TODO: if date in local xml is same as date in remote xml then don't save to disk
    // TODO: should I ever re-grab the albumArt from the server?

    return loadAllFeedsFromDisk();
  }

  //*********************************************

  void refreshFeed(String localDir)
  {
    
  }

  //*********************************************
  //*********************************************
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
  //*********************************************
  //*********************************************

  String getImgURLFromXML(XmlDocument xml)
  {
    // first element is <rss> then second element is <channel>
    XmlElement? channel = xml.firstElementChild?.firstElementChild;

    // try the <image> element first
    XmlElement? image = channel?.getElement("image");
    XmlElement? url = image?.getElement("url");
    if (url != null)
    {
      return url.innerText;
    }
    
    // next try the <itunes:image> element
    image = channel?.getElement("itunes:image");
    if (image != null)
    {
      return image.attributes.first.value;
    }

    throw Exception("could not find image url in xml");
  }

  //*********************************************

  String getFeedTitle(XmlDocument xml)
  {
    // this is a slower version of getting the channel element
    //XmlElement? rss = xml.getElement("rss");
    //XmlElement? channel = rss?.getElement("channel");

    // this is a faster version of getting the channel element
    XmlElement? channel = xml.firstElementChild?.firstElementChild;
    XmlElement? title = channel?.getElement("title");
    if (title != null)
    {
      return title.innerText;  
    }

    throw Exception("could not find title in xml");
  }

  //*********************************************

  String getFeedAuthor(XmlDocument xml)
  {
    // first element is <rss> then second element is <channel>
    XmlElement? channel = xml.firstElementChild?.firstElementChild;
    XmlElement? author = channel?.getElement("itunes:author");
    if (author != null)
    {
      return author.innerText;
    }

    throw Exception("could not find author in xml");
  }

  //*********************************************

  String getFeedDescription(XmlDocument xml)
  {
    // first element is <rss> then second element is <channel>
    XmlElement? channel = xml.firstElementChild?.firstElementChild;
    XmlElement? description = channel?.getElement("description");
    if (description != null)
    {
      return removeHtmlTags(description.innerText);
    }

    throw Exception("could not find description in xml");
  }

  //*********************************************

  List<Episode> getEpisodes(XmlDocument xml)
  {
    XmlElement? channel = xml.firstElementChild?.firstElementChild;
    if (channel != null)
    {
      var items = channel.findElements("item");
      List<Episode> episodes = [];
      for (var item in items)
      {
        XmlElement? title = item.getElement("title");
        XmlElement? description = item.getElement("description");
        XmlElement? pubDate = item.getElement("pubDate");
        if (title != null && description != null && pubDate != null)
        {
          String descriptionNoHtml = removeHtmlTags(description.innerText);
          DateTime date = stringToDateTime(pubDate.innerText);
          episodes.add(Episode(
            // TODO: get localPath only if it has been downloaded
            localPath: "", 
            title: title.innerText, 
            description: description.innerText, 
            descriptionNoHtml: descriptionNoHtml,
            date: date)
          );
        }

        // TODO: only get the 10 most recent episodes? some feeds have ALL the episodes
        if (episodes.length >= 10)
        {
          break;
        }
      }
      return episodes;
    }

    // TODO: throw Exception or return empty List?
    throw Exception("could not find episodes");
  }

  //*********************************************
  //*********************************************
  //*********************************************

  String removeHtmlTags(String input)
  {
    // . means wildcard
    // dotAll means the wildcard . will match all characters including line terminators
    // *? means non-greedy version of * (* means 0 or more)
    // .*? means 0 or more of any char, it will match the least amount of chars
    RegExp re = RegExp(r"<.*?>", dotAll: true);
    String result = input.replaceAll(re, "");
    result = result.replaceAll("&amp;", "&");
    return result.trim();
  }

  //*********************************************
  //*********************************************
  //*********************************************

  // TODO: separate the storage vs network functions?

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
}
