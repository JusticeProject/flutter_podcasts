import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'data_structures.dart';
import 'utilities.dart';

//*************************************************************************************************

class DataModel extends ChangeNotifier
{
  int _highestFeedNumber = -1;
  
  List<Feed> _feedList = [];
  List<Feed> get feedList => _feedList;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool get isBusy => (_isInitializing || _isRefreshing);

  //*********************************************

  // Constructor
  DataModel()
  {
    _loadAllFeedsFromDisk();
  }

  //*********************************************
  //*********************************************
  //*********************************************

  Future<void> addFeed(String url) async
  {
    try
    {
      _isRefreshing = true;
      notifyListeners();

      _highestFeedNumber++;
      String localDir = await getLocalPath();
      localDir = combinePaths(localDir, "$_highestFeedNumber");

      Uint8List rssBytes = await _fetchRSS(url);
      String xmlFilename = combinePaths(localDir, "feed.xml");
      await saveToFileBytes(xmlFilename, rssBytes);
      
      Feed feed = await _gatherFeedInfo(localDir, true);
      _feedList.add(feed);

      FeedConfig config = FeedConfig(url, feed.datePublishedUTC);
      saveFeedConfig(localDir, config);
    }
    catch (err)
    {
      // TODO: cleanup any folders/files that were created
      _highestFeedNumber--;
      rethrow;
    }
    finally
    {
      // for testing the button disabling
      //await Future.delayed(Duration(seconds: 5));
      _isRefreshing = false;
      notifyListeners();
    }
  }

  //*********************************************

  Future<void> removeFeed(int index) async
  {
    // TODO: what if the files are in use? what if the .mp3 is playing right now? I should stop (all?) playback first
    // maybe during loading I could remove files/folders that are marked for deletion
    // or run some background task that periodically tries to remove them
    // what if folder 10 is the highest numbered folder and it's marked for removal but then user wants to add a podcast at the end of the list?

    try
    {
      Feed feedToRemove = _feedList.removeAt(index);
      await Directory(feedToRemove.localDir).delete(recursive: true);
      notifyListeners();
    }
    catch (err)
    {
      logDebugMsg("Exception in removeFeed: ${err.toString()}");
    }
  }

  //*********************************************

  Future<void> refreshAllFeeds() async
  {
    _isRefreshing = true;
    notifyListeners();

    bool needToLoadFromDisk = false;

    for (Feed feed in _feedList)
    {
      bool feedHasNewData = await _refreshFeed(feed);
      needToLoadFromDisk = needToLoadFromDisk || feedHasNewData;
    }

    if (needToLoadFromDisk)
    {
      await _loadAllFeedsFromDisk();
    }

    _isRefreshing = false;
    notifyListeners();
  }

  //*********************************************

  // return true if it was refreshed with new data, false otherwise
  Future<bool> _refreshFeed(Feed feed) async
  {
    // TODO: what if I have the 10th episode downloaded then the feed updates so it's now the 11th episode? should I delete the 11th episode?
    // TODO: const MAX_EPISODES = 10? then use it here and in getEpisodes()

    // TODO: try/catch?

    // TODO: if number of episodes is different between local and remote XML then save xml to disk?
    // TODO: should I ever re-grab the albumArt from the server?

    FeedConfig config = await loadFeedConfig(feed.localDir);
    Uint8List rssBytes = await _fetchRSS(config.url);
    String rssText = String.fromCharCodes(rssBytes);
    XmlDocument xml = XmlDocument.parse(rssText);
    String remotePubDate = _getPubDate(xml);
    DateTime remoteDatePublishedUTC = stringToDateTimeUTC(remotePubDate);

    if (isExpired(config.datePublishedUTC, remoteDatePublishedUTC))
    {
      logDebugMsg("saving new XML for ${feed.title}");
      String xmlFilename = combinePaths(feed.localDir, "feed.xml");
      await saveToFileBytes(xmlFilename, rssBytes);
      config.datePublishedUTC = remoteDatePublishedUTC;
      saveFeedConfig(feed.localDir, config);
      return true;
    }
    else
    {
      logDebugMsg("${feed.title} already up to date");
      return false;
    }

    // TODO: allow user to refresh a single feed? if so need notifyListeners
    //notifyListeners();
  }

  //*********************************************
  //*********************************************
  //*********************************************

  Future<Feed> _gatherFeedInfo(String localDir, bool downloadAlbumArt) async
  {
    String feedNumberString = getFileNameFromPath(localDir);
    int feedNumberInt = int.parse(feedNumberString);

    String xmlFilename = combinePaths(localDir, "feed.xml");
    String text = await readFileString(xmlFilename);
    XmlDocument xml = XmlDocument.parse(text);

    String imgFilename = combinePaths(localDir, "albumArt.jpg");
    if (downloadAlbumArt)
    {
      String imgURL = _getImgURLFromXML(xml);
      Uint8List imgBytes = await _fetchAlbumArt(imgURL);
      await saveToFileBytes(imgFilename, imgBytes);
    }

    String title = _getFeedTitle(xml);
    String author = _getFeedAuthor(xml);
    String description = _getFeedDescription(xml);
    //logDebugMsg("found title $title");
    List<Episode> episodes = _getEpisodes(xml);

    String dateString = _getPubDate(xml);
    DateTime dateUTC = stringToDateTimeUTC(dateString);

    Feed feed = Feed(feedNumberInt, localDir, title, author, description, Image.file(File(imgFilename)), dateUTC, episodes);
    return feed;
  }

  //*********************************************

  Future<void> _loadAllFeedsFromDisk() async
  {
    _feedList = [];
    var path = await getLocalPath();
    var dir = Directory(path);
    var itemStream = dir.list();

    // TODO: need a try/catch here, it may not have been caught in addPodcast because the new xml was downloaded later which is missing info
    // But then I won't be able to display the episodes, should I keep a backup of the old xml file?
    // try/catch is also needed so the app doesn't crash on loading

    // TODO: should I move the below to loadFeedFromDisk?

    await for (var item in itemStream)
    {
      if (item is Directory)
      {
        Feed feed = await _gatherFeedInfo(item.path, false);
        _feedList.add(feed);
      }
    }

    _feedList.sort((a, b) => a.feedNumber.compareTo(b.feedNumber));

    if (_feedList.isNotEmpty)
    {
      _highestFeedNumber = _feedList.last.feedNumber;
    }

    logDebugMsg("_highestFeedNumber = $_highestFeedNumber");

    // for testing the circular progress indicator
    //await Future.delayed(Duration(seconds: 5));
    _isInitializing = false;
    notifyListeners();
  }

  //*********************************************

  Future<void> saveFeedConfig(String localDir, FeedConfig config) async
  {
    localDir = combinePaths(localDir, "config.txt");
    await saveToFileString(localDir, config.toString());
  }

  //*********************************************

  Future<FeedConfig> loadFeedConfig(String localDir) async
  {
    localDir = combinePaths(localDir, "config.txt");

    String data = await readFileString(localDir);
    FeedConfig config = FeedConfig.fromExisting(data);
    return config;
  }

  //*********************************************
  //*********************************************
  //*********************************************

  String _getPubDate(XmlDocument xml)
  {
    // first element is <rss> then second element is <channel>
    XmlElement? channel = xml.firstElementChild?.firstElementChild;
    XmlElement? pubDate = channel?.getElement("pubDate");
    if (pubDate != null)
    {
      return pubDate.innerText;
    }

    // if there is no top level pubDate then try the first item
    XmlElement? item = channel?.getElement("item");
    if (item != null)
    {
      XmlElement? pubDate = item.getElement("pubDate");
      if (pubDate != null)
      {
        return pubDate.innerText;
      }
    }

    // TODO: or should I just use a pubDate of .now()? could cause issues if a new podcast is released but they use a date before .now()

    throw Exception("could not find pubDate in xml");
  }

  //*********************************************

  String _getImgURLFromXML(XmlDocument xml)
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

  String _getFeedTitle(XmlDocument xml)
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

  String _getFeedAuthor(XmlDocument xml)
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

  String _getFeedDescription(XmlDocument xml)
  {
    // first element is <rss> then second element is <channel>
    XmlElement? channel = xml.firstElementChild?.firstElementChild;
    XmlElement? description = channel?.getElement("description");
    if (description != null)
    {
      return _removeHtmlTags(description.innerText);
    }

    throw Exception("could not find description in xml");
  }

  //*********************************************

  List<Episode> _getEpisodes(XmlDocument xml)
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
          String descriptionNoHtml = _removeHtmlTags(description.innerText);
          DateTime dateUTC = stringToDateTimeUTC(pubDate.innerText);
          episodes.add(Episode(
            // TODO: get localPath only if it has been downloaded
            localPath: "", 
            title: title.innerText, 
            description: description.innerText, 
            descriptionNoHtml: descriptionNoHtml,
            datePublishedUTC: dateUTC)
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

  String _removeHtmlTags(String input)
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

  Future<Uint8List> _fetchRSS(String url) async
  {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode ~/ 100 != 2)
    {
      throw Exception("Error when fetching RSS at $url: ${resp.statusCode}");
    }
    return resp.bodyBytes;
  }

  //*********************************************

  Future<Uint8List> _fetchAlbumArt(String url) async
  {
    final resp = await http.get(Uri.parse(url));
    return resp.bodyBytes;
  }
}
