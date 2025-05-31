import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

//*************************************************************************************************

class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context)
  {
    var client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
    return client;
  }
}

//*************************************************************************************************

void main(List<String> args) async
{
  List<String> names = await loadAllAlbumArt();
  for (var name in names)
  {
    print(name);
  }

  print("main done");
}

//*************************************************************************************************

Future<List<String>> loadAllAlbumArt() async
{
  List<String> names = [];
  var dir = Directory("bin");
  var items = dir.list();
  await for (var item in items)
  {
    if ((item is File) && (item.path.contains(".jpg")))
    {
      names.add(item.path);
    }
  }

  names.sort((a, b) {
    // - if less
    // 0 if equal
    // + if greater
    if (a.length > b.length)
    {
      return 1;
    }
    else if (a.length < b.length)
    {
      return -1;
    }
    else 
    {
      return a.compareTo(b);
    }
  });

  return names;
}

//*************************************************************************************************

Future<void> updateAll() async
{
  HttpOverrides.global = MyHttpOverrides();

  Map<String, String> feeds = {
    "0": "https://feeds.twit.tv/sn.xml",
    "1" : "https://feeds.twit.tv/uls.xml",
    "2" : "https://feeds.megaphone.fm/gamescoop",
    "3" : "https://feeds.simplecast.com/6WD3bDj7",
    "4" : "https://feeds.simplecast.com/JT6pbPkg",
    "5" : "https://makingembeddedsystems.libsyn.com/rss",
    "6" : "https://talkpython.fm/episodes/rss",
    "7" : "https://www.sciencefriday.com/feed/podcast/science-friday/",
    "8" : "https://feeds.megaphone.fm/ignbeyond",
    "9" : "https://feeds.megaphone.fm/ignunlocked",
    "10" : "https://feeds.megaphone.fm/unfiltered",
    "11" : "https://feeds.megaphone.fm/nvc"
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
}

//*************************************************************************************************

Future<void> updateFeed(String name, String url) async
{
  Uint8List rssBytes = await fetchRSS(url);
  String xmlFilename = "bin${Platform.pathSeparator}$name.xml";
  await saveToFile(xmlFilename, rssBytes);
  
  String text = await readFile(xmlFilename);
  XmlDocument xml = XmlDocument.parse(text);

  String imgURL = getImgURLFromXML(xml);
  Uint8List imgBytes = await fetchAlbumArt(imgURL);
  String imgFilename = "bin${Platform.pathSeparator}$name.jpg";
  await saveToFile(imgFilename, imgBytes);

  String title = getPodcastTitle(xml);
  print(title);
}

//*************************************************************************************************

Future<void> saveToFile(String filename, Uint8List bytes) async
{
  File fd = File(filename);
  await fd.writeAsBytes(bytes);
}

//*************************************************************************************************

Future<String> readFile(String filename) async
{
  File fd = File(filename);
  return await fd.readAsString();
}

//*************************************************************************************************

String getImgURLFromXML(XmlDocument xml)
{
  var elements = xml.findAllElements("image");
  if (elements.isNotEmpty)
  {
    var urls = elements.first.findElements("url");
    if (urls.isNotEmpty)
    {
      return urls.first.innerText;
    }
  }

  elements = xml.findAllElements("itunes:image");
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

//*************************************************************************************************

String getPodcastTitle(XmlDocument xml)
{
  var elements = xml.findAllElements("title");
  if (elements.isNotEmpty)
  {
    return elements.first.innerText;
  }

  throw Exception("could not find title in xml");
}

//*************************************************************************************************

Future<Uint8List> fetchRSS(String url) async
{
  final resp = await http.get(Uri.parse(url));
  return resp.bodyBytes;
}

//*************************************************************************************************

Future<Uint8List> fetchAlbumArt(String url) async
{
  final resp = await http.get(Uri.parse(url));
  return resp.bodyBytes;
}

//*************************************************************************************************
