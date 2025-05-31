import 'package:flutter/material.dart';
import 'utilities.dart' as utilities;

//*************************************************************************************************

void main()
{
  // TODO:
  utilities.disableCertError();

  runApp(const PodcastApp());
}

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

class LibraryPage extends StatefulWidget
{
  const LibraryPage({super.key});

  final String title = "Library";

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

//*************************************************************************************************

class _LibraryPageState extends State<LibraryPage>
{
  late Future<List<Image>> _albumCovers;

  void _addPodcast() async
  {
    for (var feed in feeds.entries)
    {
      try
      {
        await utilities.updateFeed(feed.key, feed.value);
        utilities.logDebugMsg("${feed.key} done");
      }
      catch (err)
      {
        utilities.logDebugMsg("Exception!! ${feed.key} ${err.toString()}");
      }

    }

    setState(() {
      _albumCovers = utilities.loadAlbumArt();
    });
  }

  @override
  void initState() {
    super.initState();
    _albumCovers = utilities.loadAlbumArt();
  }

  @override
  Widget build(BuildContext context)
  {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // for dark theme the colors are:
    // primary = purple
    // inversePrimary = black
    // onPrimary = black

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: FutureBuilder(
          future: _albumCovers,
          builder: (context, snapshot) {
            if (snapshot.hasData)
            {
              return GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                padding: EdgeInsets.all(10),
                children: [
                  // TODO: android.permission.READ_EXTERNAL_STORAGE ??
                  //Image.asset("assets/examples/Security Now.jpg")
                  for (var img in snapshot.data!)
                    img
                ],
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
        backgroundColor: Colors.white, // specify the color behind the +
        foregroundColor: colorScheme.onPrimary, // specify the color of the +
        onPressed: _addPodcast,
        icon: const Icon(Icons.add),
      )
    );
  }
}

// RSS feeds:
Map<String, String> feeds = {
  "Security Now": "https://feeds.twit.tv/sn.xml",
  "The Untitled Linux Show" : "https://feeds.twit.tv/uls.xml",
  "Game Scoop!" : "https://feeds.megaphone.fm/gamescoop",
  "Triple Click" : "https://feeds.simplecast.com/6WD3bDj7",
  "Google DeepMind" : "https://feeds.simplecast.com/JT6pbPkg",
  "Embedded.fm" : "https://makingembeddedsystems.libsyn.com/rss",
  "Talk Python to Me" : "https://talkpython.fm/episodes/rss"
};
