import 'package:flutter/material.dart';

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
      home: const HomePage(title: 'Library'),
    );
  }
}

//*************************************************************************************************

class HomePage extends StatefulWidget
{
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

//*************************************************************************************************

class _HomePageState extends State<HomePage>
{
  int _counter = 0;

  void _incrementCounter()
  {
    setState(() {
      _counter++;
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
        onPressed: _incrementCounter,
        icon: const Icon(Icons.add),
      )
    );
  }
}

// RSS feeds:
// https://feeds.twit.tv/sn.xml
// https://feeds.twit.tv/uls.xml
// https://feeds.megaphone.fm/gamescoop
// https://feeds.simplecast.com/6WD3bDj7   // triple click
// https://feeds.simplecast.com/JT6pbPkg   // is this correct for deepmind?
// https://makingembeddedsystems.libsyn.com/rss
// https://talkpython.fm/episodes/rss
