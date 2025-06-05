import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'feed_page.dart';
import 'data_structures.dart';
import 'utilities.dart';
import 'data_model.dart';

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
    return ChangeNotifierProvider(
      create: (context) => DataModel(),
      child: MaterialApp(
        title: 'Simple Podcasts App',
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: ThemeData(colorScheme: ColorScheme.dark()),
        home: LibraryPage(scaffoldMessengerKey: _scaffoldMessengerKey),
        debugShowCheckedModeBanner: false,
      ),
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
  final ScrollController _scrollController = ScrollController();
  List<Feed> _feedList = [];
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  //*******************************************************

  void _showMessageToUser(String msg)
  {
    // widget in this case refers to the corresponding StatefulWidget
    widget.scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text(msg), duration: Duration(seconds: 10)));
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
      _showMessageToUser(err.toString());
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
    /*setState(() {
      _isRefreshing = true;
    });*/

    void futureError(err)
    {
      _showMessageToUser(err.toString());
    }

    Future<void> future = dataModel.refreshAllFeeds().catchError(futureError);
    return future;
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

    //var dataModel = context.watch<DataModel>();
    DataModel dataModel = Provider.of<DataModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [IconButton(onPressed: () => _onPopulateLibrary(dataModel), icon: Icon(Icons.rss_feed))],
      ),
      body: SafeArea(
        child: Center(
          child: Consumer<DataModel>(
            builder: (context, dataModel, child)
            {
              if (dataModel.isInitializing)
              {
                return const CircularProgressIndicator();
              }

              if (!dataModel.isRefreshing)
              {
                _feedList = dataModel.feedList;
              }
  
              return RefreshIndicator(
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
                    return GestureDetector(
                      // disable tapping on each albumArt while refreshing
                      onTap: dataModel.isBusy ? null : () => 
                        Navigator.push(context, MaterialPageRoute(builder: (context) => FeedPage(feed: _feedList[index]))),
                      onLongPress: dataModel.isBusy ? null : () => 
                        showRemoveFeedDialog(context, _feedList[index].title, index, _onRemoveFeed), 
                      child: FeedPreview(feed: _feedList[index])
                    );
                  }
                ),
              );
            }
          )
        )
      ),
      // TODO: can I dynamically switch from extended to regular FloatingAction button? the extended covers up the bottom podcast text
      floatingActionButton: Consumer<DataModel>(
        builder: (context, dataModel, child) {
          return FloatingActionButton.extended(
            label: Text("Add podcast"),
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
            const Text("Enter the URL of the RSS feed:"),
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
