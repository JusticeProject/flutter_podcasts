import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_structures.dart';
import 'utilities.dart';
import 'xml_reader.dart';

// TODO: audio player shows on lockscreen, stops playing when headphones removed, try this package
// https://pub.dev/packages/audio_service

//*************************************************************************************************

// WidgetsBindingObserver gives didChangeAppLifecycleState and didRequestAppExit
class DataModel extends ChangeNotifier with WidgetsBindingObserver
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

  Episode? _currentEpisode;
  Episode? get currentEpisode => _currentEpisode;

  // this scaffold messenger key is used to show the SnackBar (toast) outside of a build function since otherwise 
  // we would need the BuildContext
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _playbackPositionSubscription;
  StreamSubscription<void>? _playbackCompleteSubscription;

  late SharedPreferencesWithCache _playbackPositionCache;

  //*********************************************

  // Constructor
  DataModel()
  {
    WidgetsBinding.instance.addObserver(this);
    // we won't wait in the constructor but inside the initialize function we will wait
    initialize();
  }

  //*********************************************

  // "Destructor"
  @override
  void dispose()
  {
    // saving playback info in dispose didn't seem to work

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //*********************************************

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async
  {
    // see https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html
    //logDebugMsg("state change: $state");
    
    // the paused state happens way too often, even when the podcast is still playing,
    // when going from the app to the home screen: inactive -> hidden -> paused
    // when coming back to the app: hidden -> inactive -> resumed
    // saving playback positions if the app state changes to detached didn't seem to work
    /*if (state == AppLifecycleState.detached)
    {
      for (Feed feed in _feedList)
      {
        try
        {
          await savePlaybackPositions(feed);
        }
        catch (err)
        {
          logDebugMsg(err.toString());
        }
      }
    }*/
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async
  {
    // function wasn't called on Android
    logDebugMsg("!! Exiting !!");
    return super.didRequestAppExit();
  }

  //*******************************************************

  Future<void> initialize() async
  {
    try
    {
      // I'm using SharedPreferencesWithCache instead of the Async version because I don't want to write to disk too often:
      // "SharedPreferencesAsync does not utilize a local cache which causes all calls to be asynchronous calls to the 
      // host platforms storage solution."
      _playbackPositionCache = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());
      await _loadAllFeedsFromDisk();
    }
    catch (err)
    {
      logDebugMsg("failed initial load of feeds");
      _failedToLoad = true;
      showMessageToUser(err.toString());
    }
  }

  //*********************************************

  void showMessageToUser(String msg)
  {
    logDebugMsg(msg);
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
      
      Feed feed = await _gatherFeedInfo(localDir, true, false);
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
    try
    {
      for (Episode episode in _feedList[index].episodes)
      {
        if (episode.isPlaying || episode.isDownloading)
        {
          throw Exception("Can't remove feed while downloading/playing");
        }
      }

      Feed feedToRemove = _feedList.removeAt(index);

      // if the current episode in the miniplayer is from this feed then remove it from the miniplayer
      if (_currentEpisode != null && _currentEpisode!.localDir == feedToRemove.localDir)
      {
        _currentEpisode = null;
      }

      await Directory(feedToRemove.localDir).delete(recursive: true);
      notifyListeners();
      removeSavedPlaybackPositions(feedToRemove);
    }
    catch (err)
    {
      logDebugMsg("Exception in removeFeed: ${err.toString()}");
      rethrow;
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

  Future<Feed> _gatherFeedInfo(String localDir, bool downloadAlbumArt, bool updatePlaybackPositions) async
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
    Image albumArt = Image.file(File(imgFilename));
    List<Episode> episodes = await getFeedEpisodes(xml, localDir, albumArt);

    String dateString = getFeedPubDate(xml);
    DateTime dateUTC = stringToDateTimeUTC(dateString);

    Feed feed = Feed(feedNumberInt, localDir, title, author, description, albumArt, dateUTC, episodes);

    // update the number of episodes that have been downloaded
    for (Episode episode in episodes)
    {
      if (episode.filename.isNotEmpty)
      {
        feed.numEpisodesOnDisk++;
      }
    }

    // assuming MAX_NUM_EPISODES = 10:
    // If I have the 10th episode downloaded then the feed updates so it's now the 11th episode, need to delete the 11th
    // episode because it won't be visible to the user anymore. We'll do this by deleting any episodes from the filesystem 
    // that don't correspond to an Episode in the current Feed.
    await _removeOldEpisodes(feed);

    // update the playback positions for each episode that were stored in the cache
    if (updatePlaybackPositions)
    {
      await loadPlaybackPositions(feed);
    }

    // if the current episode in the mini player belongs to this feed we need to update it with the new Episode object we just created
    _updateCurrentEpisode(feed);
    
    return feed;
  }

  //*********************************************

  void _updateCurrentEpisode(Feed feed)
  {
    if (_currentEpisode != null && _currentEpisode!.localDir == feed.localDir)
    {
      for (Episode episode in feed.episodes)
      {
        if (episode.filename == _currentEpisode!.filename)
        {
          logDebugMsg("mini player updated with new current episode");
          _currentEpisode = episode;
          return;
        }
      }
    }
  }

  //*********************************************

  Future<void> _removeOldEpisodes(Feed feed) async
  {
    try
    {
      var itemStream = Directory(feed.localDir).list();
      await for (var item in itemStream)
      {
        if (item is File && !item.path.endsWith(".jpg") && !item.path.endsWith(".txt") && !item.path.endsWith(".xml"))
        {
          // we found an episode file, now check if the filename matches a guid
          String filename = getFileNameFromPath(item.path);
          Episode? episode = _getEpisodeByGuid(feed.episodes, filename);
          if (episode == null)
          {
            // no matching episode, delete the file
            logDebugMsg("deleting outdated file $filename from feed ${feed.title}");
            await File(item.path).delete();

            // check if the file we just deleted is currently being used by the mini player
            if (_currentEpisode != null && _currentEpisode!.localDir == feed.localDir && _currentEpisode!.guid == filename)
            {
              logDebugMsg(("removing deleted file from the mini player"));
              _currentEpisode = null;
            }
          }
        }
      }
    }
    catch (err)
    {
      logDebugMsg(err.toString());
    }
  }

  //*********************************************

  // if passing in a filename for guid then it shouldn't have any "/" characters or parent folders, just the name of the file
  Episode? _getEpisodeByGuid(List<Episode> episodes, String guid)
  {
    // could maybe use episodes.firstWhere but this seems cleaner
    for (Episode episode in episodes)
    {
      if (episode.guid == guid)
      {
        return episode;
      }
    }

    return null;
  }

  //*********************************************

  Future<void> _loadAllFeedsFromDisk() async
  {
    // when the apps starts (whether it's the first time or millionth time) the feed list will be empty
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
            // There's an oat_primary folder which causes an Exception since it can't be converted to a number, not
            // sure why it's there. Just skip it since the SnackBar msg will confuse the user.
            if (getFileNameFromPath(item.path) == "oat_primary")
            {
              logDebugMsg("skipping oat_primary folder");
            }
            else
            {
              Feed feed = await _gatherFeedInfo(item.path, false, true);
              _feedList.add(feed);
            }
          }
          catch (err)
          {
            showMessageToUser("folder ${item.path} had error: ${err.toString()}");
          }
        }
      }

      _feedList.sort((a, b) => a.feedNumber.compareTo(b.feedNumber));

      if (_feedList.isNotEmpty)
      {
        _highestFeedNumber = _feedList.last.feedNumber;
      }

      logDebugMsg("_highestFeedNumber = $_highestFeedNumber");

      // if there is an episode that has playback position information then load it into the mini player
      initializeCurrentEpisode();

      // for testing the circular progress indicator
      //await Future.delayed(Duration(seconds: 5));
      _isInitializing = false;
      notifyListeners();
    }
    else
    {
      // we are *re*loading
      for (int i = 0; i < _feedList.length; i++)
      {
        // we should only reload a feed if it isn't playing
        if (_feedList[i].isPlaying)
        {
          logDebugMsg("skipping load of feed ${_feedList[i].title} since it's playing");
        }
        else
        {
          // load the feed 
          _feedList[i] = await _gatherFeedInfo(_feedList[i].localDir, false, true);
        }
      }
    }
  }

  //*********************************************

  void initializeCurrentEpisode()
  {
    for (Feed feed in _feedList)
    {
      for (Episode episode in feed.episodes)
      {
        if (episode.playbackPosition.inSeconds > 0)
        {
          // just use the first one we find
          _currentEpisode = episode;
          return;
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

  // alternative option for saving playbackPositions:
  // https://api.flutter.dev/flutter/widgets/RestorationMixin-mixin.html
  // https://docs.flutter.dev/platform-integration/android/restore-state-android

  // TODO: when should I save the playback positions? whenever an episode is paused or complete? (I could pass in a bool to pauseEpisode
  // so it saves when you press the pause button but not when you press play when a different episode is already playing - it pauses the first
  // episode before playing the second episode)
  // or save playback position before reloading a feed? 
  // or during DataModel's destructor/dispose? or when the state changes to detached?
  Future<void> savePlaybackPositions(Feed feed) async
  {
    // https://docs.flutter.dev/cookbook/persistence/key-value

    String key = feed.feedNumber.toString();

    List<String> values = [];
    for (Episode episode in feed.episodes)
    {
      if (episode.playbackPosition.inMicroseconds > 0 || episode.played)
      {
        // format is:
        // guid,seconds played,total seconds in file,played
        String value = 
          "${episode.guid},${episode.playbackPosition.inSeconds},${episode.playLength?.inSeconds ?? 0},${episode.played ? "1" : "0"}";
        values.add(value);
      }
    }

    if (values.isNotEmpty)
    {
      await _playbackPositionCache.setStringList(key, values);
    }
  }

  //*********************************************

  Future<void> loadPlaybackPositions(Feed feed) async
  {
    String key = feed.feedNumber.toString();

    try
    {
      List<String>? values = _playbackPositionCache.getStringList(key);
      if (values != null)
      {
        logDebugMsg("found playback info for ${feed.title}");
        for (String value in values)
        {
          List<String> valueSplit = value.split(",");
          String guid = valueSplit[0];
          Duration playbackPosition = Duration(seconds: int.parse(valueSplit[1]));
          int lengthSeconds = int.parse(valueSplit[2]);
          Duration? playLength = (lengthSeconds == 0) ? null : Duration(seconds: lengthSeconds);
          bool played = valueSplit[3] == "1" ? true : false;

          Episode? episode = _getEpisodeByGuid(feed.episodes, guid);
          if (episode != null)
          {
            episode.playbackPosition = playbackPosition;
            episode.playLength = playLength;
            episode.played = played;
          }
        }
      }
    }
    catch (err)
    {
      logDebugMsg(err.toString());
    }
  }

  //*********************************************

  Future<void> removeSavedPlaybackPositions(Feed feed) async
  {
    String key = feed.feedNumber.toString();
    if (_playbackPositionCache.containsKey(key))
    {
      await _playbackPositionCache.remove(key);
    }
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
      http.StreamedResponse streamedResponse = await client.send(request).timeout(Duration(seconds: 120));
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
        if (numChunksReceived % 100 == 0)
        {
          // the UI can update the download progress every x chunks received
          episode.downloadProgress = math.min(bytesReceived / bytesExpected, 1.0);
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
    if (_currentEpisode == episode)
    {
      _currentEpisode = null;
    }

    // if episode is playing, pause it first
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

  void showMiniPlayer(Episode episode)
  {
    _currentEpisode = episode;
    notifyListeners();
  }

  //*********************************************
  //*********************************************
  //*********************************************

  Future<void> playEpisode(Episode episode) async
  {
    // First check if a file is already playing. If so it's probably a different file, so this will pause it and 
    // update that Episode's state
    if (_audioPlayer.state == PlayerState.playing)
    {
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

    // if refreshing then don't continue because the episode they are trying to play might get deleted
    if (isRefreshing)
    {
      throw Exception("Please wait for the refresh to finish");
    }

    // This is a callback that we will register soon. It will be called periodically while the episode is playing
    // to give us updates on the current position in the file.
    void onPlaybackPositionUpdates(Duration d)
    {
      if (episode.isPlaying)
      {
        // Notify the listeners so they can update their progress bar.
        episode.playbackPosition = d;
        notifyListeners();
      }
    }

    // This is a callback that we will register soon. It will be called when an Episode finished playing.
    void onPlaybackComplete(void nothing) async
    {
      await _playbackCompleteSubscription?.cancel(); // cancel this callback so we don't get called again
      await _playbackPositionSubscription?.cancel();
      logDebugMsg("playback complete");
      episode.isPlaying = false;
      Feed feed = _getFeedOfEpisode(episode);
      feed.isPlaying = false;
      episode.played = true;
      episode.playbackPosition = Duration(); // if we play the Episode again it will start at the beginning
      _currentEpisode = null;
      notifyListeners();
      await savePlaybackPositions(feed);
    }

    // AudioPlayer API usage:
    // https://pub.dev/packages/audioplayers
    // https://github.com/bluefireteam/audioplayers/blob/main/getting_started.md
    // alternative audio package, doesn't work on Windows: https://pub.dev/packages/just_audio

    logDebugMsg("${episode.title} will start at ${episode.playbackPosition}");

    // Register one callback before we start playing. Don't want a scenario where we start playing and the episode finishes
    // but we haven't registered the onPlayerComplete callback yet, thus we wouldn't get a chance to save some info.
    _playbackCompleteSubscription = _audioPlayer.onPlayerComplete.listen(onPlaybackComplete);

    String fullLocalPath = combinePaths(episode.localDir, episode.filename);
    await _audioPlayer.play(DeviceFileSource(fullLocalPath), position: episode.playbackPosition);
    episode.playLength = await _audioPlayer.getDuration();
    // Register for position updates only after it has started playing and we have the total duration of the file
    _playbackPositionSubscription = _audioPlayer.onPositionChanged.listen(onPlaybackPositionUpdates);
    
    logDebugMsg("now playing at position ${await _audioPlayer.getCurrentPosition()}");
    episode.isPlaying = true;
    _getFeedOfEpisode(episode).isPlaying = true;
    episode.played = false;
    notifyListeners();
  }

  //*********************************************

  Future<void> pauseEpisode(Episode episode) async
  {
    episode.isPlaying = false;
    Feed feed = _getFeedOfEpisode(episode);
    feed.isPlaying = false;

    // The order seems critical here:
    // pause the audio player, the position updates should stop arriving soon,
    // cancel the position update subscription so we don't get any erroneous values, 
    // cancel the playbackComplete callback last after the player has finished pausing so we don't miss a critical state change
    await _audioPlayer.pause();
    await _playbackPositionSubscription?.cancel();
    await _playbackCompleteSubscription?.cancel();

    logDebugMsg("${episode.title} paused at ${episode.playbackPosition}");
    notifyListeners();

    await savePlaybackPositions(feed);
  }

  //*********************************************

  Future<void> seekEpisode(Episode episode, Duration newPosition) async
  {
    logDebugMsg("user requested seek to $newPosition");

    // set it now since the onPositionChanged callback registered in playEpisode may not be called for a few milliseconds,
    // set it before and after the seek to prevent the progress bar from jumping for a split second.
    // I could also pause/resume the position update subscription
    episode.playbackPosition = newPosition;
    await _audioPlayer.seek(newPosition);
    episode.playbackPosition = newPosition;
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
