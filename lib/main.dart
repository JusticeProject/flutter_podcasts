import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu.dart';
import 'feed_page.dart';
import 'data_structures.dart';
import 'utilities.dart';
import 'data_model.dart';
import 'spectrum_bars.dart';
import 'common_widgets.dart';

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

void main()
{
  //debugPaintSizeEnabled = true; // Enables layout lines
  disableCertError();

  // disable http fetching of the Google fonts, add the license for the Google font
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/UFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });

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
      // https://pub.dev/packages/google_fonts
      // https://fonts.google.com/specimen/Ubuntu
      theme: ThemeData(
        colorScheme: ColorScheme.dark(primary: const Color(0xff03dac6)), 
        textTheme: GoogleFonts.ubuntuTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white, decorationColor: Colors.white),
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
  late int _tapCount;
  late DateTime _lastTapTime;

  //*******************************************************

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollPositionChanged);
    _tapCount = 0;
    _lastTapTime = DateTime.now();
  }

  //*******************************************************

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
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
        try
        {
          await dataModel.addFeed(url);
        }
        catch (err)
        {
          dataModel.showMessageToUser(err.toString());
        }
      }
    }
  }

  //*******************************************************

  Future<void> _onNewFeed(DataModel dataModel, String url) async
  {
    try
    {
      // we'll wait for this to complete
      await dataModel.addFeed(url);

      // we won't wait for this: scroll to the bottom of the list after a delay to give time for 
      // the build function to set the size of the grid view
      Future.delayed(Duration(seconds: 1), () {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent + 1000, 
          duration: Duration(seconds: 2), curve: Curves.fastOutSlowIn);
      });
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  Future<void> _onRemoveFeed(DataModel dataModel, int index) async
  {
    try
    {
      await dataModel.removeFeed(index);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  Future<void> _onRefresh(DataModel dataModel) async
  {
    try
    {
      await dataModel.refreshAllFeeds();
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
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
    // surface = black-ish but not pure black, it's the normal background color
    // onPrimary = black

    //var dataModel = context.watch<DataModel>();
    DataModel dataModel = Provider.of<DataModel>(context, listen: false);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          actions: [IconButton(onPressed: () => _onPopulateLibrary(dataModel), icon: Icon(Icons.rss_feed)), Menu()],
        ),
        body: Consumer<DataModel>(
          builder: (context, dataModel, child)
          {
            if (dataModel.failedToLoad)
            {
              return Center(child: Icon(Icons.warning, size: 50, color: Colors.amber));
            }
        
            if (dataModel.isInitializing)
            {
              return Center(child: const CircularProgressIndicator());
            }
          
            // wrap the GridView with RefreshIndicator which allows you to swipe down to refresh
            return RefreshIndicator(
              // if DataModel is downloading then the refresh will stop immediately
              onRefresh: () => _onRefresh(dataModel),
              child: Container(
                margin: EdgeInsets.only(bottom: 80), // when the persistent bottom sheet is displayed we need room to scroll lower
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
                  itemCount: dataModel.feedList.length,
                  itemBuilder: (context, index) {
                    Feed feed = dataModel.feedList[index];
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
              ),
            );
          }
        ),
        floatingActionButton: Consumer<DataModel>(
          builder: (context, dataModel, child) {
            return Container(
              margin: EdgeInsets.only(bottom: 75), // move the button up in case the MiniPlayer is visible
              child: FloatingActionButton.extended(
                label: Text("Add podcast"),
                isExtended: _showExtendedButton, // dynamically switch from extended to regular FloatingActionButton based on scroll position
                // we disable the Add Podcast button when the library of feeds is loading or already adding a new one
                onPressed: dataModel.isBusy ? null : () => showAddFeedDialog(context, _onNewFeed),
                icon: const Icon(Icons.add),
              ),
            );  
          },
          
        ),
        bottomSheet: Consumer<DataModel>(
          builder: (context, dataModel, child) {
            if (dataModel.currentEpisode != null)
            {
              return MiniPlayer(episode: dataModel.currentEpisode!);
            }
            else
            {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
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
            const Text("To add a podcast, enter the URL of the RSS feed:", style: TextStyle(fontWeight: FontWeight.bold)),
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
                TextButton(
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)), 
                  onPressed: () {Navigator.of(context).pop();}
                ),
                TextButton(
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
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
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
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
// "https://feeds.twit.tv/twig.xml", // This Week in Google -> Intelligent Machines
"https://feeds.twit.tv/uls.xml", // The Untitled Linux Show
// "https://feeds.libsyn.com/499093/rss", // FLOSS Weekly
"https://feeds.simplecast.com/6WD3bDj7", // Triple Click
"https://feeds.simplecast.com/JT6pbPkg", // Google DeepMind
// Google AI Release Notes
"https://makingembeddedsystems.libsyn.com/rss", // Embedded.fm
"https://talkpython.fm/episodes/rss", // Talk Python to Me
// "https://pythonbytes.fm/episodes/rss", // Python Bytes
// "https://feeds.simplecast.com/4T39_jAj", // Star Talk
"https://pinecast.com/feed/the-minnmax-show", // The MinnMax Show
"https://feeds.megaphone.fm/gamescoop", // Game Scoop!
// "https://feeds.megaphone.fm/ignbeyond", // Beyond!
// "https://feeds.megaphone.fm/ignunlocked", // Podcast Unlocked (Xbox)
// "https://feeds.megaphone.fm/nvc", // Nintendo Voice Chat
// "https://feeds.megaphone.fm/ignconsolewatch", // Next-Gen Console Watch
"https://feeds.npr.org/510289/podcast.xml", // Planet Money
// "https://feeds.npr.org/510325/podcast.xml", // The Indicator (NPR)
// "https://feeds.simplecast.com/h18ZIZD_", // Science Friday
// "https://www.thisamericanlife.org/podcast/rss.xml", // This American Life
// "https://feeds.megaphone.fm/search-engine", // Search Engine
// "https://feeds.megaphone.fm/kindafunnypodcast", // Kinda Funny Podcast
// "https://feeds.megaphone.fm/ROOSTER8838278962", // Kinda Funny Games Daily
// "https://feeds.megaphone.fm/STU5682506591", // Sacred Symbols (Playstation)
// "https://feeds.libsyn.com/78795/rss", // Dev Game Club
// "https://eightfour.libsyn.com/rss", // 8-4 Play
// "https://letscast.fm/podcasts/rust-in-production-82281512/feed", // Rust In Production
// "https://rustacean-station.org/podcast.rss", // Rustacean Station
// "https://feeds.transistor.fm/fallthrough", // Fallthrough (Go)
// "https://feeds.acast.com/public/shows/4d1eb966-6f07-4562-b9f1-9fd512f9631e", // Abroad in Japan
// "https://feeds.blubrry.com/feeds/power_up_eetimes.xml", // PowerUp / EETimes
// "https://feeds.simplecast.com/8fQdS6Dx", // MIT Chalk Radio
// "https://www.numberphile.com/podcast?format=rss", // Numberphile
"https://lexfridman.com/feed/podcast/", // Lex Fridman
"https://feeds.megaphone.fm/LILLL9002079998", // Shane Smith has Questions
"https://feeds.megaphone.fm/theezrakleinshow", // Vox the Gray Area
// Bangkok Podcast
// Hidden Experience
// Foundation for Middle East Peace (FMEP)
// Above and Beyond, Armin, Tiesto, Gareth Emery, Paul van Dyk
];
