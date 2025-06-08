import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:audioplayers/audioplayers.dart';

import 'data_structures.dart';
import 'utilities.dart';
import 'xml_reader.dart';

//*************************************************************************************************

class DataModel extends ChangeNotifier
{
  // Keeps track of what feedNumber to use next when adding a new podcast feed. Each podcast is stored in its own
  // directory, with the directory name being "0" or "5" which corresponds to its feedNumber;
  int _highestFeedNumber = -1;
  
  final List<Feed> _feedList = []; // we can still add to the list even though it's marked as final
  List<Feed> get feedList => _feedList;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;
  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;
  bool get isBusy => (_isInitializing || _isRefreshing);

  bool _failedToLoad = false;
  bool get failedToLoad => _failedToLoad;

  // this scaffold messenger key is used to show the SnackBar (toast) outside of a build function since otherwise 
  // we would need the BuildContext
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _playbackPositionSubscription;

  //*********************************************

  // Constructor
  DataModel()
  {
    _loadAllFeedsFromDisk().catchError(
      (err)
      {
        logDebugMsg("failed initial load of feeds");
        _failedToLoad = true;
        showMessageToUser(err.toString());
      }
    );
  }

  //*********************************************

  void showMessageToUser(String msg)
  {
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(msg), duration: Duration(seconds: 10)));
    notifyListeners();
  }

  //*********************************************
  //*********************************************
  //*********************************************

  Future<void> addFeed(String url) async
  {
    String localDir = "";

    try
    {
      _isRefreshing = true;
      notifyListeners();

      _highestFeedNumber++;
      localDir = await getLocalPath();
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
      // cleanup any folders/files that were created
      if (localDir.isNotEmpty && await Directory(localDir).exists())
      {
        await Directory(localDir).delete(recursive: true);
        logDebugMsg("directory removed");
      }

      _highestFeedNumber--;
      rethrow; // even with this rethrow the finally clause still runs
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
    // don't continue with the refresh if any Feeds are downloading episodes
    for (Feed feed in _feedList)
    {
      if (feed.numEpisodesDownloading > 0)
      {
        return;
      }
    }

    _isRefreshing = true;
    notifyListeners();

    String? errorMsg;

    List<bool> feedHasNewData = List<bool>.filled(_feedList.length, false);

    for (int i = 0; i < _feedList.length; i++)
    {
      try
      {
        if (_feedList[i].isPlaying)
        {
          logDebugMsg("skipping refresh of ${_feedList[i].title} since it's playing");
        }
        else
        {
          feedHasNewData[i] = await _refreshFeed(_feedList[i]);
        }
      }
      catch (err)
      {
        errorMsg = "Error refreshing ${_feedList[i].title}: ${err.toString()}";
      }
    }

    for (int i = 0; i < feedHasNewData.length; i++)
    {
      if (feedHasNewData[i])
      {
        try
        {
          await _loadAllFeedsFromDisk();
        }
        catch (err)
        {
          errorMsg = "Error loading after refreshing: ${err.toString()}";
        }

        // only load once
        break;
      }
    }

    for (int i = 0; i < _feedList.length; i++)
    {
      _feedList[i].newEpisodesOnLastRefresh |= feedHasNewData[i];
    }

    _isRefreshing = false;
    notifyListeners();

    if (errorMsg != null)
    {
      throw Exception(errorMsg);
    }
  }

  //*********************************************

  // return true if it was refreshed with new data, false otherwise
  Future<bool> _refreshFeed(Feed feed) async
  {
    // TODO: what if I have the 10th episode downloaded then the feed updates so it's now the 11th episode? should I delete the 11th episode?
    // use MAX_NUM_EPISODES
    // also, what if they change an episode's guid thus it won't match the local filename?

    // TODO: if number of episodes is different between local and remote XML then save xml to disk? (they didn't update the pubDate)

    FeedConfig config = await loadFeedConfig(feed.localDir);
    Uint8List rssBytes = await _fetchRSS(config.url);
    String rssText = String.fromCharCodes(rssBytes);
    XmlDocument xml = XmlDocument.parse(rssText);
    String remotePubDate = getFeedPubDate(xml);
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
      String imgURL = getAlbumArtURL(xml);
      Uint8List imgBytes = await _fetchAlbumArt(imgURL);
      await saveToFileBytes(imgFilename, imgBytes);
    }

    String title = getFeedTitle(xml);
    String author = getFeedAuthor(xml);
    String description = getFeedDescription(xml);
    //logDebugMsg("found title $title");
    List<Episode> episodes = await getFeedEpisodes(xml, localDir);

    String dateString = getFeedPubDate(xml);
    DateTime dateUTC = stringToDateTimeUTC(dateString);

    Feed feed = Feed(feedNumberInt, localDir, title, author, description, Image.file(File(imgFilename)), dateUTC, episodes);

    // update the number of episodes that have been downloaded
    for (Episode episode in episodes)
    {
      if (episode.filename.isNotEmpty)
      {
        feed.numEpisodesOnDisk++;
      }
    }

    return feed;
  }

  //*********************************************

  Future<void> _loadAllFeedsFromDisk() async
  {
    // first time loading the list will be empty
    if (_feedList.isEmpty)
    {
      var path = await getLocalPath();
      var dir = Directory(path);
      var itemStream = dir.list();

      await for (var item in itemStream)
      {
        if (item is Directory)
        {
          // Continue loading even if some feeds failed to load. Some feeds might have missing info which throws an exception.
          // We'll show a message to the user when it happens.
          try
          {
            Feed feed = await _gatherFeedInfo(item.path, false);
            _feedList.add(feed);
          }
          catch (err)
          {
            showMessageToUser(err.toString());
          }
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
    else
    {
      for (int i = 0; i < _feedList.length; i++)
      {
        // we should only reload a feed if it isn't playing
        if (_feedList[i].isPlaying)
        {
          logDebugMsg("skipping load of feed ${_feedList[i].title} since it's playing");
        }
        else
        {
          // TODO: use the old Feed to copy information to the new Feed object, like each Episode's playbackPosition/played information
          // A helper function could be used for that: copyPlaybackInfo, will need to see that the Episode's guid matches before each copy.
          _feedList[i] = await _gatherFeedInfo(_feedList[i].localDir, false);
        }
      }
    }
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
    if (resp.statusCode ~/ 100 != 2)
    {
      throw Exception("Error when fetching album art at $url: ${resp.statusCode}");
    }
    return resp.bodyBytes;
  }

  //*********************************************

  Future<void> fetchEpisode(Episode episode) async
  {
    // find the Feed associated with this episode
    Feed feed = _getFeedOfEpisode(episode);
    // this will prevent user from refreshing while downloading, that would cause too many side effects
    feed.numEpisodesDownloading++;
    episode.isDownloading = true;
    episode.downloadProgress = 0.0;
    notifyListeners();

    try
    {
      // use guid for filename
      String fullLocalPath = combinePaths(episode.localDir, episode.guid);

      logDebugMsg("starting download for url ${episode.url}");
      await _smartFetchEpisode(episode, fullLocalPath);
      logDebugMsg("done saving file to localDir");

      // once it successfully downloads, update the filename in the Episode
      episode.filename = episode.guid;

      // update the number of episodes downloaded for the feed
      feed.numEpisodesOnDisk++;
    }
    catch (err)
    {
      logDebugMsg(err.toString());
      rethrow; // even with rethrow the finally clause still runs
    }
    finally
    {
      episode.isDownloading = false;
      feed.numEpisodesDownloading--;

      logDebugMsg("Episode and Feed updated, notifying listeners");
      notifyListeners();
    }
  }

  //*********************************************

  Future<void> _smartFetchEpisode(Episode episode, String localFilename) async
  {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(episode.url));
    request.maxRedirects = 15; // default is 5, some podcast CDNs redirect us more than 5, so use a safe number

    File file = File(localFilename);
    IOSink sink = file.openWrite(mode: FileMode.write);

    try
    {
      // throws an Exception on timeout
      http.StreamedResponse streamedResponse = await client.send(request).timeout(Duration(seconds: 60));
      if (streamedResponse.statusCode ~/ 100 != 2)
      {
        throw Exception("statusCode = ${streamedResponse.statusCode}");
      }

      // The stream is the response body data, no headers. As bytes come in write them to disk, this is faster 
      // and uses less RAM than http.get followed by File.writeAsBytes. Plus, we can show progress of download.
      double bytesReceived = 0.0;
      double bytesExpected = streamedResponse.contentLength?.toDouble() ?? 1.0;
      int numChunksReceived = 0;
      await for (List<int> dataChunk in streamedResponse.stream)
      {
        // write data chunk to the file we already opened
        sink.add(dataChunk);

        bytesReceived += dataChunk.length;
        numChunksReceived++;
        if (numChunksReceived % 1000 == 0)
        {
          // the UI can update the download progress every 1000 chunks
          episode.downloadProgress = bytesReceived / bytesExpected;
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      
      //http.Response response = await http.Response.fromStream(streamedResponse);
      //print('Status code: ${response.statusCode}');
      //print('Body Length: ${response.body.length}');
    }
    catch (err)
    {
      logDebugMsg(err.toString());
      await sink.flush();
      await sink.close();
      await File(localFilename).delete();
      // TODO: how do I test partial download?
      rethrow; // even with rethrow the finally clause still runs
    }
    finally
    {
      client.close();
    }
  }

  //*********************************************

  Future<void> removeEpisode(Episode episode) async
  {
    // if episode is playing, pause it first
    // TODO: maybe I should stop the episode instead of pause
    if (episode.isPlaying)
    {
      await pauseEpisode(episode);
    }

    if (episode.filename.isNotEmpty)
    {
      String fullLocalPath = combinePaths(episode.localDir, episode.filename);
      if (await File(fullLocalPath).exists())
      {
        await File(fullLocalPath).delete();
        episode.filename = "";
        Feed feed = _getFeedOfEpisode(episode);
        feed.numEpisodesOnDisk--;
        notifyListeners();
      }
    }
  }

  //*********************************************
  //*********************************************
  //*********************************************

  Future<void> playEpisode(Episode episode) async
  {
    if (_audioPlayer.state == PlayerState.playing)
    {
      // a different file is probably playing, pause it and keep that position, also mark it as not playing
      for (Feed feed in _feedList)
      {
        for (Episode episode in feed.episodes)
        {
          if (episode.isPlaying)
          {
            await pauseEpisode(episode);
          }
        }
      }
    }

    // AudioPlayer API usage:
    // https://pub.dev/packages/audioplayers
    // https://github.com/bluefireteam/audioplayers/blob/main/getting_started.md

    String fullLocalPath = combinePaths(episode.localDir, episode.filename);
    await _audioPlayer.setSourceDeviceFile(fullLocalPath);
    await _audioPlayer.seek(episode.playbackPosition);
    logDebugMsg("done seeking to ${episode.playbackPosition}");
    await _audioPlayer.resume();
    _playbackPositionSubscription = _audioPlayer.onPositionChanged.listen((Duration d)
      {
        // TODO: notifyListeners when there is a progress bar
        episode.playbackPosition = d;
      });
    
    // TODO: set the callback for when playback is done, set episode.isPlaying = false, set episode.played = true, notifyListeners
    
    logDebugMsg("now playing");
    episode.isPlaying = true;
    _getFeedOfEpisode(episode).isPlaying = true;
    notifyListeners();
  }

  //*********************************************

  Future<void> pauseEpisode(Episode episode) async
  {
    episode.isPlaying = false;
    _getFeedOfEpisode(episode).isPlaying = false;
    await _playbackPositionSubscription?.cancel();
    await _audioPlayer.pause();
    logDebugMsg("now paused");
    notifyListeners();
  }

  //*********************************************
  //*********************************************
  //*********************************************

  Feed _getFeedOfEpisode(Episode episode)
  {
    Feed feed = _feedList.firstWhere((element) => element.localDir == episode.localDir);
    return feed;
  }
}
