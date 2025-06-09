import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'menu.dart';
import 'feed_page.dart';
import 'data_structures.dart';
import 'utilities.dart';
import 'data_model.dart';
import 'spectrum_bars.dart';

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

void main()
{
  //debugPaintSizeEnabled = true; // Enables layout lines
  disableCertError();

  runApp(
    ChangeNotifierProvider(
      create: (context) => DataModel(),
      child: PodcastApp()
    )
  );
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class PodcastApp extends StatelessWidget
{
  const PodcastApp({super.key});
  
  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: 'Simple Podcasts App',
      scaffoldMessengerKey: Provider.of<DataModel>(context, listen: false).scaffoldMessengerKey,
      // could try a different font, maybe textTheme: GoogleFonts.latoTextTheme() from google_fonts package:
      // https://pub.dev/packages/google_fonts
      theme: ThemeData(
        colorScheme: ColorScheme.dark(primary: const Color(0xff03dac6)), 
        fontFamily: 'serif'
      ),
      home: LibraryPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class LibraryPage extends StatefulWidget
{
  const LibraryPage({super.key});

  final String title = "Library";

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class _LibraryPageState extends State<LibraryPage>
{
  late final ScrollController _scrollController;
  bool _showExtendedButton = true;
  late List<Feed> _feedList;
  late int _tapCount;
  late DateTime _lastTapTime;

  //*******************************************************

  @override
  void initState() {
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollPositionChanged);
    _feedList = [];
    _tapCount = 0;
    _lastTapTime = DateTime.now();
    super.initState();
  }

  //*******************************************************

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
    _feedList = [];
    super.dispose();
  }

  //*******************************************************

  void _onScrollPositionChanged()
  {
    //logDebugMsg("${_scrollController.offset} / ${_scrollController.position.maxScrollExtent}");

    // if we are far away from the bottom (max scroll extent) then we can show the fully extended "Add podcast" button
    bool shouldBeExtended = (_scrollController.offset < (_scrollController.position.maxScrollExtent - 100));

    // only update when we cross the threshold
    if (_showExtendedButton != shouldBeExtended)
    {
      setState(() {
        _showExtendedButton = shouldBeExtended;
      });
    }
  }

  //*******************************************************

  Future<void> _onPopulateLibrary(DataModel dataModel) async
  {
    DateTime now = DateTime.now();
    if (now.difference(_lastTapTime).inSeconds < 3)
    {
      _tapCount++;
      logDebugMsg("tap count is $_tapCount");
    }
    else
    {
      _tapCount = 0;
      logDebugMsg("tap count reset to 0");
    }
    _lastTapTime = now;
    
    if (_tapCount > 6)
    {
      _tapCount = 0;

      for (String url in urls)
      {
        await dataModel.addFeed(url);
      }
    }
  }

  //*******************************************************

  void _onNewFeed(DataModel dataModel, String url)
  {
    void futureDone(value)
    { 
      // scroll to the bottom of the list but add a delay to give time for 
      // the build function to set the size of the grid view
      Future.delayed(Duration(seconds: 1), () {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent + 1000, 
          duration: Duration(seconds: 2), curve: Curves.fastOutSlowIn);
      });
    }

    void futureError(err)
    {
      dataModel.showMessageToUser(err.toString());
    }

    dataModel.addFeed(url).then(futureDone).catchError(futureError);
  }

  //*******************************************************

  void _onRemoveFeed(DataModel dataModel, int index)
  {
    dataModel.removeFeed(index);
  }

  //*******************************************************

  Future<void> _onRefresh(DataModel dataModel)
  {
    void futureError(err)
    {
      dataModel.showMessageToUser(err.toString());
    }

    Future<void> future = dataModel.refreshAllFeeds().catchError(futureError);
    return future;
  }

  //*******************************************************

  void _onFeedPreviewTapped(BuildContext context, Feed feed)
  {
    Navigator.push(context, MaterialPageRoute(builder: (context) => FeedPage(feed: feed)));

    if (feed.newEpisodesOnLastRefresh)
    {
      setState(() {
        // When tapping the FeedPreview we need to clear the newEpisode status.
        feed.newEpisodesOnLastRefresh = false;
      });
    }
  }

  //*******************************************************

  // TODO: if user rotates the phone to landscape then
  // if MediaQuery.sizeOf(context).width > height or
  // > 1000 then use more grid count,
  // or wrap with a LayoutBuilder which provides the context/constraints
  // or Display class https://api.flutter.dev/flutter/dart-ui/Display-class.html

  @override
  Widget build(BuildContext context)
  {
    //final theme = Theme.of(context);
    //final colorScheme = theme.colorScheme;
    // for dark theme the colors are:
    // primary = purple
    // inversePrimary = black
    // onPrimary = black

    //var dataModel = context.watch<DataModel>();
    DataModel dataModel = Provider.of<DataModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [IconButton(onPressed: () => _onPopulateLibrary(dataModel), icon: Icon(Icons.rss_feed)), Menu()],
      ),
      body: SafeArea(
        child: Center(
          child: Consumer<DataModel>(
            builder: (context, dataModel, child)
            {
              if (dataModel.failedToLoad)
              {
                return Icon(Icons.warning, size: 50, color: Colors.amber);
              }

              if (dataModel.isInitializing)
              {
                return const CircularProgressIndicator();
              }

              if (!dataModel.isRefreshing)
              {
                _feedList = dataModel.feedList;
              }
  
              // wrap the GridView with RefreshIndicator which allows you to swipe down to refresh
              return RefreshIndicator(
                // if DataModel is downloading then the refresh will stop immediately
                onRefresh: () => _onRefresh(dataModel),
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(), // this ensures you can drag down to refresh even if the library is too small to scroll
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    mainAxisSpacing: 20, 
                    crossAxisSpacing: 18,
                    childAspectRatio: 0.8, // changes it from square to rectangular, with more space vertically for the text below the albumArt
                  ),
                  controller: _scrollController,
                  padding: EdgeInsets.all(18),
                  itemCount: _feedList.length,
                  itemBuilder: (context, index) {
                    Feed feed = _feedList[index];
                    return GestureDetector(
                      // disable tapping on each albumArt while refreshing
                      onTap: dataModel.isBusy ? null : () => _onFeedPreviewTapped(context, feed),
                      // disable removing the podcast feed while refreshing, or while downloading episodes for this feed
                      onLongPress: (dataModel.isBusy || feed.numEpisodesDownloading > 0) ? null : () => 
                        showRemoveFeedDialog(context, feed.title, index, _onRemoveFeed), 
                      child: FeedPreview(feed: feed)
                    );
                  }
                ),
              );
            }
          )
        )
      ),
      floatingActionButton: Consumer<DataModel>(
        builder: (context, dataModel, child) {
          return FloatingActionButton.extended(
            label: Text("Add podcast"),
            isExtended: _showExtendedButton, // dynamically switch from extended to regular FloatingActionButton based on scroll position
            // we disable the Add Podcast button when the library of feeds is loading or already adding a new one
            onPressed: dataModel.isBusy ? null : () => showAddFeedDialog(context, _onNewFeed),
            icon: const Icon(Icons.add),
          );  
        },
        
      )
    );
  }
}

//*************************************************************************************************

class FeedPreview extends StatelessWidget
{
  const FeedPreview({super.key, required this.feed});

  final Feed feed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        feed.isPlaying ? Stack(children: [feed.albumArt, SizedBox(width: 40, height: 25, child: SpectrumBars())]) : feed.albumArt,
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "${feed.numEpisodesOnDisk} episode${feed.numEpisodesOnDisk == 1 ? '' : 's'}",
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              SizedBox(width: 10),
              if (feed.newEpisodesOnLastRefresh)
                Icon(Icons.circle, size: 9, color: Theme.of(context).colorScheme.primary)
            ],
          ),
        ),
      ],
    );
  }
}

//*************************************************************************************************

void showAddFeedDialog(BuildContext context, void Function(DataModel dataModel, String url) onNewFeed)
{
  String url = "";
  // don't need to call watch for the DataModel
  DataModel dataModel = Provider.of<DataModel>(context, listen: false);

  showModalBottomSheet(
    context: context,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return Container(
        padding: EdgeInsets.fromLTRB(20, 120, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("To add a podcast, enter the URL of the RSS feed:"),
            TextField(autofocus: true,
              onChanged: (value) {
                url = value;
              },
              onSubmitted: (value) {
                if (url.isNotEmpty) {
                  onNewFeed(dataModel, url);
                  Navigator.of(context).pop();
                }
              },
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(child: const Text('Cancel'), onPressed: () {Navigator.of(context).pop();}),
                TextButton(child: const Text('Add'),
                  onPressed: () {
                    if (url.isNotEmpty) {
                      onNewFeed(dataModel, url);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
            Spacer(),
          ],
        ),
      );
    },
  );
}

//*************************************************************************************************

void showRemoveFeedDialog(BuildContext context, String title, int index, void Function(DataModel dataModel, int index) onRemoveFeed)
{
  // don't need to call watch for the DataModel
  DataModel dataModel = Provider.of<DataModel>(context, listen: false);
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Remove $title from library?"),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Remove'),
            onPressed: () {
              onRemoveFeed(dataModel, index);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

//*************************************************************************************************

// my default RSS feeds
List<String> urls = [
"https://feeds.twit.tv/sn.xml", // Security Now
"https://feeds.twit.tv/twig.xml", // This Week in Google -> Intelligent Machines
"https://feeds.twit.tv/uls.xml", // The Untitled Linux Show
// FLOSS Weekly
"https://feeds.simplecast.com/6WD3bDj7", // Triple Click
"https://feeds.simplecast.com/JT6pbPkg", // Google DeepMind
// Google AI Release Notes
"https://makingembeddedsystems.libsyn.com/rss", // Embedded.fm
"https://talkpython.fm/episodes/rss", // Talk Python to Me
// Python Bytes
"https://feeds.simplecast.com/4T39_jAj", // StarTalk
"https://pinecast.com/feed/the-minnmax-show", // The MinnMax Show
"https://feeds.megaphone.fm/gamescoop", // Game Scoop!
"https://feeds.megaphone.fm/ignbeyond", // Beyond!
"https://feeds.megaphone.fm/ignunlocked", // Podcast Unlocked (Xbox)
"https://feeds.megaphone.fm/unfiltered", // IGN Unfiltered
"https://feeds.megaphone.fm/nvc", // Nintendo Voice Chat
"https://feeds.megaphone.fm/ignconsolewatch", // Next-Gen Console Watch
"https://feeds.npr.org/510289/podcast.xml", // Planet Money
"https://feeds.npr.org/510325/podcast.xml", // The Indicator (NPR)
"https://feeds.simplecast.com/h18ZIZD_", // Science Friday
// Stuff You Should Know
// This American Life
"https://feeds.megaphone.fm/kindafunnypodcast", // Kinda Funny Podcast
"https://feeds.megaphone.fm/ROOSTER8838278962", // Kinda Funny Games Daily
// Sacred Symbols (Playstation)
// Dev Game Club
// 8-4 Play
// Rust In Production
// Rustacean Station
// Fallthrough (Go)
// Abroad in Japan
// PowerUp / EETimes
"https://feeds.simplecast.com/8fQdS6Dx", // MIT Chalk Radio
// Numberphile
// Lex Friedman
// Bangkok Podcast
// Hidden Experience
// Foundation for Middle East Peace (FMEP)
// Above and Beyond, Armin, Tiesto, Gareth Emery, Paul van Dyk
];
