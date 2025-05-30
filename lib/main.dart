import 'package:flutter/material.dart';
import 'fetch.dart' as fetch;
import 'utilities.dart' as utilities;

//*************************************************************************************************

void main()
{
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

  void _addPodcast() async
  {
    feeds.forEach((key, value) async {
      try
      {
        String xml = await fetch.fetchRSS(value);
        await utilities.saveFile("$key.xml", xml.codeUnits);
      }
      catch (err)
      {
        utilities.logDebugMsg(err.toString());
      }
    });

    setState(() {
      // TODO:
    });
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
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          padding: EdgeInsets.all(10),
          children: [
            Image.asset("assets/examples/sn.jpg"),
            Image.asset("assets/examples/uls.jpg"),
            Image.asset("assets/examples/gs.jpg"),
            Image.asset("assets/examples/tc.jpg"),
            Image.asset("assets/examples/dm.jpg"),
            Image.asset("assets/examples/em.jpg"),
            Image.asset("assets/examples/py.jpg")
          ],
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
  "Embedded.cmd" : "https://makingembeddedsystems.libsyn.com/rss",
  "Talk Python to Me" : "https://talkpython.fm/episodes/rss"
};
