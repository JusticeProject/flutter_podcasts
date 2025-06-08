import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  final url = Uri.parse(
    'https://www.podtrac.com/pts/redirect.mp3/pdst.fm/e/chrt.fm/track/FGADCC/pscrb.fm/rss/p/tracking.swap.fm/track/bwUd3PHC9DH3VTlBXDTt/traffic.megaphone.fm/SBP7591503528.mp3?updated=1749335536');

  final client = http.Client();
  final request = http.Request('GET', url);
  print("Default maxRedirects: ${request.maxRedirects}");
  request.maxRedirects = 10;

  try
  {
    http.StreamedResponse streamedResponse = await client.send(request).timeout(Duration(seconds: 60));
    print("contentLength = ${streamedResponse.contentLength}");
    print("statusCode = ${streamedResponse.statusCode}");

    int counter = 0;
    File file = File("C:\\Users\\mozde\\Desktop\\test.mp3");
    IOSink sink = file.openWrite(mode: FileMode.write);

    // the stream is the response body data, no headers
    int numChunks = 0;
    await for (List<int> dataChunk in streamedResponse.stream)
    {
      //print("dataChunk.length = ${dataChunk.length}");
      sink.add(dataChunk);
      counter += dataChunk.length;
      numChunks++;
    }
    // was 73793316, now 74362785
    print("counter = $counter");
    print("numChunks = $numChunks");
    await sink.flush();
    await sink.close();
    

    //http.Response response = await http.Response.fromStream(streamedResponse);
    //print('Status code: ${response.statusCode}');
    //print('Body Length: ${response.body.length}');
  }
  catch (err)
  {
    print(err.toString());
  }
  finally
  {
    client.close();
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
