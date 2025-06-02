import 'package:flutter/material.dart';
import 'podcast_page.dart';
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
      Podcast newPodcast = await _storageHandler.addPodcast(url);
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
      _storageHandler.removePodcast(podcastToRemove);
    });

    logDebugMsg("done with _onRemovePodcast");
  }

  //*******************************************************

  @override
  void initState() {
    super.initState();
    _futurePodcastList = _storageHandler.loadPodcasts();
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
      body: SafeArea(
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  mainAxisSpacing: 20, 
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.8, // changes it from square to rectangular, with more space vertically for the text below the albumArt
                ),
                controller: _scrollController,
                padding: EdgeInsets.all(18),
                itemCount: _podcastList.length,
                itemBuilder: (context, index) {
                  // TODO: could use GridTile wrapped around InkWell wrapped around image to show an animation when long pressing
                  // TODO: show number of episodes downloaded below each album art
                  return GestureDetector(
                    onTap: () => 
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PodcastPage(podcast: _podcastList[index]))),
                    onLongPress: () => 
                      showRemovePodcastDialog(context, _podcastList[index].title, index, _onRemovePodcast), 
                    child: PodcastPreview(podcast: _podcastList[index])
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

class PodcastPreview extends StatelessWidget
{
  const PodcastPreview({super.key, required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        podcast.albumArt,
        // TODO: it would be nice to display the title too, but due to the unforseen lengths this can cause out of bounds issues
        /*Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Text(podcast.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),*/
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Text(
            "${podcast.numEpisodesDownloaded} episode${podcast.numEpisodesDownloaded == 1 ? '' : 's'}",
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
        ),
      ],
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



// TODO list:

// General:
// use const Widget whenever possible to reduce screen rebuild time

/////////////////////////////////////////////////////////////////////////////////////////

// Library page:
// Refresh, drag down on main Library page

// if user rotates the phone to landscape then
// if MediaQuery.sizeOf(context).width > height or
// > 1000 then use more grid count,
// or wrap with a LayoutBuilder which provides the context/constraints
// or Display class https://api.flutter.dev/flutter/dart-ui/Display-class.html

/////////////////////////////////////////////////////////////////////////////////////////

// Podcast Page:
// Refresh, drag down?
// ListView?
// ListTile or custom widget?
// IconButton(Icons.download, size: , color:), will download or remove
// Play button

/////////////////////////////////////////////////////////////////////////////////////////

// Episode Page:

/////////////////////////////////////////////////////////////////////////////////////////

// Data Storage:

// For each subscription save for offline usage:
// url and date last retrieved in a .txt file
// albumArt
// entire xml file?

/////////////////////////////////////////////////////////////////////////////////////////

// Audio player:

// audio player at bottom of each page
// audio library: https://pub.dev/packages/just_audio
// audio only, no video
// stops playing when headphones removed
// audio player shows on lockscreen
