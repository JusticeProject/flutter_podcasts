import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

//*************************************************************************************************

class MyHttpOverrides extends HttpOverrides
{
  @override
  HttpClient createHttpClient(SecurityContext? context)
  {
    var client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
    return client;
  }
}

//*************************************************************************************************

void disableCertError()
{
  if (kDebugMode)
  {
    HttpOverrides.global = MyHttpOverrides();
  }
}

//*************************************************************************************************

void logDebugMsg(String msg)
{
  if (kDebugMode)
  {
    print(msg);
  }
}

//*************************************************************************************************

Future<String> getLocalPath() async
{
  //final directory = await getApplicationDocumentsDirectory();
  //logDebugMsg(directory.path);
  // return directory.path;

  var dir1 = await getApplicationCacheDirectory();
  //logDebugMsg(dir1.path);
  return dir1.path;

  //var dir2 = await getApplicationSupportDirectory();
  //print(dir2.path);
  //var dir3 = await getExternalStorageDirectory();
  //print(dir3?.path);
  //var dir4 = await getExternalStorageDirectories();
  //print(dir4);
  //var dir5 = await getExternalCacheDirectories();
  //print(dir5);
}

//*************************************************************************************************

Future<void> updateFeed(int podcastNumber, String url) async
{
  String localDir = await getLocalPath();

  Uint8List rssBytes = await fetchRSS(url);
  String xmlFilename = "$localDir${Platform.pathSeparator}$podcastNumber.xml";
  await saveToFile(xmlFilename, rssBytes);
  
  String text = await readFile(xmlFilename);
  XmlDocument xml = XmlDocument.parse(text);

  String imgURL = getImgURLFromXML(xml);
  Uint8List imgBytes = await fetchAlbumArt(imgURL);
  String imgFilename = "$localDir${Platform.pathSeparator}$podcastNumber.jpg";
  await saveToFile(imgFilename, imgBytes);

  String title = getPodcastTitle(xml);
  logDebugMsg("found title $title");
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

Future<List<Image>> loadAlbumArt() async
{
  var path = await getLocalPath();
  var dir = Directory(path);
  var itemStream = dir.list();

  // add file names to a list, then sort, then create images list
  List<File> jpgFiles = [];
  await for (var item in itemStream)
  {
    if ((item is File) && (item.path.contains(".jpg")))
    {
      jpgFiles.add(item);
    }
  }

  jpgFiles.sort((a, b) {
    // - if less
    // 0 if equal
    // + if greater
    if (a.path.length > b.path.length)
    {
      return 1;
    }
    else if (a.path.length < b.path.length)
    {
      return -1;
    }
    else 
    {
      return a.path.compareTo(b.path);
    }
  });

  List<Image> images = [for (var jpg in jpgFiles) Image.file(jpg)];

  // for testing the circular progress indicator
  //await Future.delayed(Duration(seconds: 5));
  return images;
}
