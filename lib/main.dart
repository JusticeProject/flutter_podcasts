import 'package:flutter/material.dart';
import 'podcast.dart';
import 'utilities.dart';
import 'storage_handler.dart';

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

void main()
{
  // TODO:
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

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: 'Simple Podcasts App',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(),
      ),
      home: LibraryPage(storageHandler: storageHandler),
    );
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class LibraryPage extends StatefulWidget
{
  const LibraryPage({super.key, required this.storageHandler});

  final String title = "Library";
  final StorageHandler storageHandler;

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

  void _onNewPodcast(String url) async
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
      // TODO: notify user with a SnackBar?
      logDebugMsg("Exception!! ${err.toString()}");
    }

    logDebugMsg("done with _onNewPodcast");
  }

  //*******************************************************

  void _onDeletePodcast(int index)
  {
    logDebugMsg("_onDeletePodcast($index) called");
    setState(() {
      _podcastList.removeAt(index);
    });
    // TODO: need to delete it from the filesystem
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
                  // TODO: show dialog to confirm deletion
                  return GestureDetector(onLongPress: () => _onDeletePodcast(index), child: _podcastList[index].albumArt);
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

// RSS feeds:
/*
https://feeds.twit.tv/sn.xml
https://feeds.twit.tv/uls.xml
https://feeds.megaphone.fm/gamescoop
https://feeds.simplecast.com/6WD3bDj7
https://feeds.simplecast.com/JT6pbPkg
https://makingembeddedsystems.libsyn.com/rss
https://talkpython.fm/episodes/rss
https://www.sciencefriday.com/feed/podcast/science-friday/
https://feeds.megaphone.fm/ignbeyond
https://feeds.megaphone.fm/ignunlocked
https://feeds.megaphone.fm/unfiltered
https://feeds.megaphone.fm/nvc
*/
