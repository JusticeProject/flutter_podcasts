import 'package:flutter/material.dart';
import 'utilities.dart' as utilities;

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

void main()
{
  // TODO:
  utilities.disableCertError();

  runApp(const PodcastApp());
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
      theme: ThemeData(
        colorScheme: ColorScheme.dark(),
      ),
      home: const LibraryPage(),
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
  final ScrollController _scrollController = ScrollController();
  late Future<List<Image>> _futureAlbumCovers;
  List<Image> _albumCovers = [];

  //*******************************************************

  void _onNewPodcast(String url) async
  {
    try
    {
      int podcastNumber = (await _futureAlbumCovers).length;
      await utilities.updateFeed(podcastNumber, url);
      utilities.logDebugMsg("$podcastNumber done");
    }
    catch (err)
    {
      // TODO: notify user with a SnackBar?
      utilities.logDebugMsg("Exception!! ${err.toString()}");
    }

    setState(() {
      _futureAlbumCovers = utilities.loadAlbumArt();
    });

    // scroll to the bottom of the list when the Future completes, but add a delay to give time for 
    // the build function to set the size of the grid view
    _futureAlbumCovers.then((value) {
      utilities.logDebugMsg("future complete, setting scroll after timeout");
      Future.delayed(Duration(seconds: 1), () {
        utilities.logDebugMsg("setting scroll");
        _scrollController.animateTo(_scrollController.position.maxScrollExtent + 1000, 
          duration: Duration(milliseconds: 500), curve: Curves.linear);
      });
    });

    utilities.logDebugMsg("done with _onNewPodcast");
  }

  //*******************************************************

  void _onDeletePodcast(int index)
  {
    utilities.logDebugMsg("_onDeletePodcast($index) called");
    setState(() {
      _albumCovers.removeAt(index);
    });
    // TODO: need to delete it from the filesystem
  }

  //*******************************************************

  @override
  void initState() {
    super.initState();
    _futureAlbumCovers = utilities.loadAlbumArt();
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
          future: _futureAlbumCovers,
          builder: (context, snapshot) {
            if (snapshot.hasData)
            {
              _albumCovers = snapshot.data!;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
                controller: _scrollController,
                padding: EdgeInsets.all(10),
                itemCount: _albumCovers.length,
                itemBuilder: (context, index) {
                  // TODO: show dialog to confirm deletion
                  return GestureDetector(onLongPress: () => _onDeletePodcast(index), child: _albumCovers[index]);
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
