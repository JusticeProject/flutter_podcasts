import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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
//*************************************************************************************************
//*************************************************************************************************

void logDebugMsg(String msg)
{
  if (kDebugMode)
  {
    print(msg);
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

DateTime stringToDateTime(String input)
{
  try
  {
    DateTime date = DateFormat("E, dd MMM yyyy HH:mm:ss").parse(input);
    return date;
  }
  catch (err)
  {
    logDebugMsg(err.toString());
    return DateTime.now();
  }
}

//*************************************************************************************************

String dateTimeToString(DateTime input)
{
  return DateFormat("E, dd MMM yyyy HH:mm:ss").format(input);
}

//*************************************************************************************************

String prettyPrintDate(DateTime date)
{
  DateTime now = DateTime.now();
  Duration diff = now.difference(date); // diff = now - date

  // TODO: what about if the date was published as a different time zone?, need to update stringToDateTime and dateTimeToString
  // TODO: add x minutes ago? or return the string "now"?

  if (diff.inHours == 1)
  {
    return "1 hour ago";
  }
  else if (diff.inHours < 24)
  {
    return "${diff.inHours} hours ago";
  }
  else if (diff.inDays == 1)
  {
    return "1 day ago";
  }
  else if (diff.inDays < 8)
  {
    return "${diff.inDays} days ago";
  }
  else if (now.year == date.year)
  {
    return DateFormat("MMM d").format(date);
  }
  else
  {
    return DateFormat("MMM d, yyyy").format(date);
  }
}

//*************************************************************************************************

bool isExpired(DateTime localCacheTime, DateTime remoteTime)
{
  return remoteTime.isAfter(localCacheTime);
}

//*************************************************************************************************

bool isExpiredString(String localCacheTime, String remoteTime)
{
  return isExpired(stringToDateTime(localCacheTime), stringToDateTime(remoteTime));
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

Future<String> getLocalPath() async
{
  // TODO: android.permission.READ_EXTERNAL_STORAGE ??
  var dir1 = await getApplicationCacheDirectory();
  //logDebugMsg(dir1.path);
  return dir1.path;
}

//*************************************************************************************************

String combinePaths(String path1, String path2)
{
  if (path1.endsWith(Platform.pathSeparator))
  {
    path1 = path1.substring(0, path1.length - 1);
  }

  if (path2.startsWith(Platform.pathSeparator))
  {
    path2 = path2.substring(1);
  }
  
  return "$path1${Platform.pathSeparator}$path2";
}

//*************************************************************************************************

String getFileNameFromPath(String fullPath)
{
  return fullPath.split(Platform.pathSeparator).last;
}

//*************************************************************************************************

Future<void> saveToFileBytes(String filename, Uint8List bytes) async
{
  File fd = await File(filename).create(recursive: true);
  await fd.writeAsBytes(bytes);
}

//*************************************************************************************************

Future<void> saveToFileString(String filename, String data) async
{
  File fd = await File(filename).create(recursive: true);
  await fd.writeAsString(data);
}

//*************************************************************************************************

Future<String> readFileString(String filename) async
{
  File fd = File(filename);
  return await fd.readAsString();
}
