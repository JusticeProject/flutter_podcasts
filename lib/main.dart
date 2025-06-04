import 'package:flutter/material.dart';
import 'feed_page.dart';
import 'data_structures.dart';
import 'utilities.dart';
import 'storage_handler.dart';

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

void main()
{
  //debugPaintSizeEnabled = true; // Enables layout lines
  disableCertError();

  runApp(PodcastApp());
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class PodcastApp extends StatelessWidget
{
  PodcastApp({super.key});
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: 'Simple Podcasts App',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(colorScheme: ColorScheme.dark()),
      home: LibraryPage(scaffoldMessengerKey: _scaffoldMessengerKey),
      debugShowCheckedModeBanner: false,
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class LibraryPage extends StatefulWidget
{
  const LibraryPage({super.key, required this.scaffoldMessengerKey});

  final String title = "Library";

  // this scaffold messenger key is used to show the SnackBar (toast) outside of a build function since otherwise 
  // we would need the BuildContext
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class _LibraryPageState extends State<LibraryPage>
{
  final StorageHandler _storageHandler = StorageHandler();
  final ScrollController _scrollController = ScrollController();
  late Future<List<Feed>> _futureFeedList;
  List<Feed> _feedList = [];
  bool _isRefreshing = true;

  //*******************************************************

  void _showMessageToUser(String msg)
  {
    // widget in this case refers to the corresponding StatefulWidget
    widget.scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text(msg)));
  }

  //*******************************************************

  Future<void> _onPopulateLibrary() async
  {
    setState(() {
      _isRefreshing = true;
    });

    for (String feed in feeds)
    {
      await _onNewFeed(feed);
    }

    setState(() {
      _isRefreshing = false;
    });
  }

  //*******************************************************

  Future<void> _onNewFeed(String url) async
  {
    setState(() {
      // disable the Add podcast button
      _isRefreshing = true;
    });

    try
    {
      Feed newFeed = await _storageHandler.addFeed(url);
      setState(() {
        _feedList.add(newFeed);
      });
      logDebugMsg("new podcast added");

      // scroll to the bottom of the list but add a delay to give time for 
      // the build function to set the size of the grid view
      Future.delayed(Duration(seconds: 1), () {
        logDebugMsg("setting scroll");
        _scrollController.animateTo(_scrollController.position.maxScrollExtent + 1000, 
          duration: Duration(seconds: 2), curve: Curves.fastOutSlowIn);
      });
    }
    catch (err)
    {
      // notify user with a SnackBar
      logDebugMsg("Exception!! ${err.toString()}");
      _showMessageToUser(err.toString());
    }

    setState(() {
      // re-enable the Add podcast button
      _isRefreshing = false;
    });

    logDebugMsg("done with _onNewFeed");
  }

  //*******************************************************

  void _onRemoveFeed(int index)
  {
    logDebugMsg("_onRemoveFeed($index) called");

    setState(() {
      Feed feedToRemove = _feedList.removeAt(index);

      // delete it from the filesystem, it's an async function but we don't need to wait for it to finish
      _storageHandler.removeFeed(feedToRemove);
    });

    logDebugMsg("done with _onRemoveFeed");
  }

  //*******************************************************

  Future<void> _onRefresh()
  {
    logDebugMsg("_onRefresh triggered");

    setState(() {
      _isRefreshing = true;
      _futureFeedList = _storageHandler.refreshAllFeeds();
    });

    // TODO: no auto downloads? no auto refresh?
    
    // when our feedList has been loaded we grab the list and re-enable the buttons
    _futureFeedList.then((value) {
      setState(() {
        _feedList = value;
        _isRefreshing = false;
      });
    });

    // calling this function will create a Future, that Future completes when the _futureFeedList Future has completed
    Future<void> convertFuture() async
    {
      await _futureFeedList;
      Future<void> newFuture = Future.value(); // this newFuture completes right away when it reaches this line
      return newFuture;
    }

    // we aren't calling await on this convertedFuture, whoever does await it will be stuck inside convertFuture()
    // on the line "await _futureFeedList" for a few seconds
    Future<void> convertedFuture = convertFuture();
    return convertedFuture;
  }

  //*******************************************************

  @override
  void initState() {
    super.initState();
    _isRefreshing = true; // disable the Add podcast button until we are finishing loading
    _futureFeedList = _storageHandler.loadAllFeedsFromDisk();

    // It's ok to register a .then() callback even though the FutureBuilder will also use the Future.
    // You can call .then() multiple times and each one will be called when the Future completes.
    _futureFeedList.then((value) 
    {
      setState(() {
        // setting _feedList here is redundant but I don't know which one will be called first: here or the FutureBuilder
        _feedList = value;
        _isRefreshing = false; // enable the Add podcast button now that _feedList has been set
      });
    });
  }

  //*******************************************************

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        // TODO: for testing only
        actions: [IconButton(onPressed: _onPopulateLibrary, icon: Icon(Icons.rss_feed))],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: _futureFeedList,
          builder: (context, snapshot) {
            if (snapshot.hasData)
            {
              // The following line of code is important: after this line runs the two variables will always refer to the same list.
              // So if I remove an item from _feedList and call setState then snapshot.data will also see that update.
              // I verified this with print("${identityHashCode(_feedList)}") and print("${identityHashCode(snapshot.data)}")
              _feedList = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () => _onRefresh(),
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
                    return GestureDetector(
                      // disable tapping on each albumArt while refreshing
                      onTap: _isRefreshing ? null : () => 
                        Navigator.push(context, MaterialPageRoute(builder: (context) => FeedPage(feed: _feedList[index]))),
                      onLongPress: _isRefreshing ? null : () => 
                        showRemoveFeedDialog(context, _feedList[index].title, index, _onRemoveFeed), 
                      child: FeedPreview(feed: _feedList[index])
                    );
                  }
                ),
              );
            }
            else if (snapshot.hasError)
            {
              return Text('${snapshot.error}');
            }
            else
            {
              return Center(child: const CircularProgressIndicator());
            }
          }
        ),
      ),
      // TODO: can I dynamically switch from extended to regular FloatingAction button? the extended covers up the bottom podcast text
      floatingActionButton: FloatingActionButton.extended(
        label: Text("Add podcast"),
        // we disable the Add Podcast button when the library of feeds is loading or already adding a new one
        onPressed: _isRefreshing ? null : () => showAddFeedDialog(context, _onNewFeed),
        icon: const Icon(Icons.add),
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
        feed.albumArt,
        // TODO: it would be nice to display the title too, but due to the unforseen lengths this can cause out of bounds issues
        // I could set the maxLines = 1, then overflow: fade or ellipsis
        /*Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Text(podcast.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),*/
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Text(
            "${feed.numEpisodesDownloaded} episode${feed.numEpisodesDownloaded == 1 ? '' : 's'}",
            style: const TextStyle(fontWeight: FontWeight.w500)
          ),
        ),
      ],
    );
  }
  
}

//*************************************************************************************************

void showAddFeedDialog(BuildContext context, void Function(String url) onNewFeed)
{
  String url = "";

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
            const Text("Enter the URL of the RSS feed:"),
            TextField(autofocus: true,
              onChanged: (value) {
                url = value;
              },
              onSubmitted: (value) {
                if (url.isNotEmpty) {
                  onNewFeed(url);
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
                      onNewFeed(url);
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

void showRemoveFeedDialog(BuildContext context, String title, int index, void Function(int index) onRemoveFeed)
{
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
              onRemoveFeed(index);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

//*************************************************************************************************

// RSS feeds:
// TODO: remove these sample feeds
List<String> feeds = [
"https://feeds.twit.tv/sn.xml",
"https://feeds.twit.tv/uls.xml",
"https://feeds.twit.tv/twig.xml",
"https://feeds.megaphone.fm/gamescoop",
"https://feeds.simplecast.com/6WD3bDj7",
"https://feeds.simplecast.com/JT6pbPkg",
"https://makingembeddedsystems.libsyn.com/rss",
"https://talkpython.fm/episodes/rss",
"https://www.sciencefriday.com/feed/podcast/science-friday/",
"https://feeds.megaphone.fm/ignbeyond",
"https://feeds.megaphone.fm/ignunlocked",
"https://feeds.megaphone.fm/unfiltered",
"https://feeds.megaphone.fm/nvc",
"https://feeds.megaphone.fm/kindafunnypodcast",
"https://feeds.npr.org/510289/podcast.xml",
];
