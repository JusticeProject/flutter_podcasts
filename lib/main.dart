import 'package:flutter/material.dart';
import 'podcast.dart';
import 'utilities.dart';
import 'storage_handler.dart';

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

void main()
{
  disableCertError();

  runApp(PodcastApp());
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class PodcastApp extends StatelessWidget
{
  PodcastApp({super.key});
  final StorageHandler storageHandler = StorageHandler();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: 'Simple Podcasts App',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(colorScheme: ColorScheme.dark()),
      home: LibraryPage(storageHandler: storageHandler, scaffoldMessengerKey: _scaffoldMessengerKey),
      debugShowCheckedModeBanner: false,
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class LibraryPage extends StatefulWidget
{
  const LibraryPage({super.key, required this.storageHandler, required this.scaffoldMessengerKey});

  final String title = "Library";
  final StorageHandler storageHandler;

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
  late Future<List<Podcast>> _futurePodcastList;
  List<Podcast> _podcastList = [];

  //*******************************************************

  void _showMessageToUser(String msg)
  {
    // widget in this case refers to the corresponding StatefulWidget
    widget.scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(content: Text(msg)));
  }

  //*******************************************************

  Future<void> _onPopulateLibrary() async
  {
    for (String feed in feeds)
    {
      await _onNewPodcast(feed);
    }
  }

  //*******************************************************

  Future<void> _onNewPodcast(String url) async
  {
    try
    {
      Podcast newPodcast = await widget.storageHandler.addPodcast(url);
      setState(() {
        _podcastList.add(newPodcast);
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

    logDebugMsg("done with _onNewPodcast");
  }

  //*******************************************************

  void _onRemovePodcast(int index)
  {
    logDebugMsg("_onRemovePodcast($index) called");

    setState(() {
      Podcast podcastToRemove = _podcastList.removeAt(index);

      // delete it from the filesystem, it's an async function but we don't need to wait for it to finish
      widget.storageHandler.removePodcast(podcastToRemove);
    });

    logDebugMsg("done with _onRemovePodcast");
  }

  //*******************************************************

  @override
  void initState() {
    super.initState();
    _futurePodcastList = widget.storageHandler.loadPodcasts();
  }

  //*******************************************************

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  //*******************************************************

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
      body: Center(
        child: FutureBuilder(
          future: _futurePodcastList,
          builder: (context, snapshot) {
            if (snapshot.hasData)
            {
              // The following line of code is important: after this line runs the two variables will always refer to the same list.
              // So if I remove an item from _podcastList and call setState then snapshot.data will also see that update.
              // I verified this with print("${identityHashCode(_podcastList)}") and print("${identityHashCode(snapshot.data)}")
              _podcastList = snapshot.data!;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
                controller: _scrollController,
                padding: EdgeInsets.all(10),
                itemCount: _podcastList.length,
                itemBuilder: (context, index) {
                  // TODO: show dialog to confirm deletion, use dedicated button for deleting?
                  // TODO: could use GridTile wrapped around InkWell wrapped around image to show an animation when long pressing
                  return GestureDetector(
                    onLongPress: () => showRemovePodcastDialog(context, _podcastList[index].title, index, _onRemovePodcast), 
                    child: _podcastList[index].albumArt
                  );
                }
              );
            }
            else if (snapshot.hasError)
            {
              return Text('${snapshot.error}');
            }
            else
            {
              return const CircularProgressIndicator();
            }
          }
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: Text("Add podcast"),
        //backgroundColor: Colors.white, // specify the color behind the +
        //foregroundColor: colorScheme.onPrimary, // specify the color of the +
        // TODO: should I disable this button until the existing podcasts are loaded? use another FutureBuilder with the same future?
        onPressed: () => showAddPodcastDialog(context, _onNewPodcast),
        icon: const Icon(Icons.add),
      )
    );
  }
}

//*************************************************************************************************

void showAddPodcastDialog(BuildContext context, void Function(String url) onNewPodcast)
{
  showDialog(
    context: context,
    builder: (BuildContext context) {
      String url = "";
      return AlertDialog(
        title: const Text("Enter the URL of the RSS feed:"),
        content: TextField(autofocus: true,
          onChanged: (value) {
            url = value;
          },
          onSubmitted: (value) {
            if (url.isNotEmpty) {
              onNewPodcast(url);
              Navigator.of(context).pop();
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Add'),
            onPressed: () {
              if (url.isNotEmpty) {
                onNewPodcast(url);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}

//*************************************************************************************************

void showRemovePodcastDialog(BuildContext context, String title, int index, void Function(int index) onRemovePodcast)
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
              onRemovePodcast(index);
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
// TODO: remove this
List<String> feeds = [
"https://feeds.twit.tv/sn.xml",
"https://feeds.twit.tv/uls.xml",
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
