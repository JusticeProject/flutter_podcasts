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
      home: const HomePage(title: 'Simple Podcasts'),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: theme.textTheme.headlineMedium,
            ),
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
