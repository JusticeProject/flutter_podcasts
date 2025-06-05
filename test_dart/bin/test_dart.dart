import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart';
import 'package:timezone/data/latest.dart' as tz;

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

DateTime stringToDateTime(String input)
{
  DateTime dateUTC = DateFormat("E, dd MMM yyyy HH:mm:ss").parse(input, true);

  if (input.length == 31)
  {
    int offsetHours = int.parse(input.substring(26, 29));
    print(offsetHours);
    dateUTC = dateUTC.subtract(Duration(hours: offsetHours));
  }
  else if (input.length == 29)
  {
    String abbreviation = input.substring(26, 29);
    if (abbreviation != "UTC" && abbreviation != "GMT")
    {
      if (abbreviation == "PDT")
      {
        dateUTC = dateUTC.subtract(Duration(hours: -7));
      }
    }
  }

  DateTime dateLocal = dateUTC.toLocal();



  //TimeZone.UTC
  //TimeZone zone = TimeZone(0, isDst: false, abbreviation: 'PDT');
  //final pdt = tz.getLocation('America/Los_Angeles');
  //return tz.TZDateTime.from(dateTimeWithoutZone, pdt);

  return dateLocal;
}

//*************************************************************************************************

void main(List<String> args) async
{
  tz.initializeTimeZones();
  // for (var entry in timeZoneDatabase.locations.entries)
  // {
  //   if (entry.key.contains("CST") || entry.key.contains("PDT") || entry.key.contains("PST") || entry.key.contains("Chicago"))
  //   {
  //     print(entry.key);
  //   }
  // }

  List<String> times = [
    "Fri, 30 May 2025 20:24:00 -0000",
    "Tue, 03 Jun 2025 21:00:05 PDT",
    "Thu, 22 May 2025 15:43:21 +0000",
    "Mon, 19 May 2025 12:00:00 -0800",
    "Fri, 29 Sep 2023 19:00:00 GMT"];

  for (String time in times)
  {
    print("converting $time");
    DateTime result = stringToDateTime(time);
    print(result);
    print(result.timeZoneName);
    print(result.timeZoneOffset);
  }

  print("main done");
}

//*************************************************************************************************

String getEpisodeDescription(XmlDocument xml)
{
  XmlElement? channel = xml.firstElementChild?.firstElementChild;
  if (channel != null)
  {
    var items = channel.findElements("item");
    for (var item in items)
    {
      XmlElement? description = item.getElement("description");
      if (description != null)
      {
        return description.innerText;
      }
    }
  }

  return "";
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
  XmlElement? rss = xml.getElement("rss");
  XmlElement? channel = rss?.getElement("channel");


  XmlElement? image = channel?.getElement("image");
  XmlElement? url = image?.getElement("url");
  if (url != null)
  {
    return url.innerText;
  }
  
  image = channel?.getElement("itunes:image");
  if (image != null)
  {
    return image.attributes.first.value;
  }

  throw Exception("could not find image url in xml");
}

//*************************************************************************************************

String getPodcastTitle(XmlDocument xml)
{
  XmlElement? rss = xml.getElement("rss");
  XmlElement? channel = rss?.getElement("channel");
  XmlElement? title = channel?.getElement("title");
  if (title != null)
  {
    return title.innerText;  
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
