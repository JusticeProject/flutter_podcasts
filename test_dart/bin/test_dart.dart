import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context)
  {
    var client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
    return client;
  }
}

void main(List<String> args) async
{
  // TODO: only if debug mode
  HttpOverrides.global = MyHttpOverrides();

  Map<String, String> feeds = {
    "Security Now": "https://feeds.twit.tv/sn.xml",
    "The Untitled Linux Show" : "https://feeds.twit.tv/uls.xml",
    "Game Scoop!" : "https://feeds.megaphone.fm/gamescoop",
    "Triple Click" : "https://feeds.simplecast.com/6WD3bDj7",
    "Google DeepMind" : "https://feeds.simplecast.com/JT6pbPkg",
    "Embedded.fm" : "https://makingembeddedsystems.libsyn.com/rss",
    "Talk Python to Me" : "https://talkpython.fm/episodes/rss"
  };

  List<String> status = [];

  for (var entry in feeds.entries)
  {
    try
    {
      await updateFeed(entry.key, entry.value);
      print("${entry.key} done");
      status.add("${entry.key} done");
    }
    catch (err)
    {
      print("Exception!! ${entry.key} ${err.toString()}");
      status.add("Exception!! ${entry.key} ${err.toString()}");
    }
  }

  for (var item in status)
  {
    print(item);
  }

  print("main done");
}

Future<void> updateFeed(String name, String url) async
{
  Uint8List rssBytes = await fetchRSS(url);
  String xmlFilename = "bin${Platform.pathSeparator}$name.xml";
  await saveToFile(xmlFilename, rssBytes);
  
  String xml = await readFile(xmlFilename);
  String imgURL = getImgURLFromXML(xml);
  
  Uint8List imgBytes = await fetchAlbumArt(imgURL);
  String imgFilename = "bin${Platform.pathSeparator}$name.jpg";
  await saveToFile(imgFilename, imgBytes);
}

Future<void> saveToFile(String filename, Uint8List bytes) async
{
  File fd = File(filename);
  await fd.writeAsBytes(bytes);
}

Future<String> readFile(String filename) async
{
  File fd = File(filename);
  return await fd.readAsString();
}

String getImgURLFromXML(String xml)
{
  XmlDocument doc = XmlDocument.parse(xml);

  var elements = doc.findAllElements("image");
  if (elements.isNotEmpty)
  {
    var urls = elements.first.findElements("url");
    if (urls.isNotEmpty)
    {
      return urls.first.innerText;
    }
  }

  elements = doc.findAllElements("itunes:image");
  if (elements.isNotEmpty)
  {
    var first = elements.first;
    if (first.attributes.isNotEmpty)
    {
      return first.attributes.first.value;
    }
  }

  throw Exception("could not find image url in xml");
}

Future<Uint8List> fetchRSS(String url) async
{
  final resp = await http.get(Uri.parse(url));
  return resp.bodyBytes;
}

Future<Uint8List> fetchAlbumArt(String url) async
{
  final resp = await http.get(Uri.parse(url));
  return resp.bodyBytes;
}