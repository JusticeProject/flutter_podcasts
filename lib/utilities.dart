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
    // TODO: in-app log msg viewer would be handy, any time logDebugMsg is called or showMessageToUser, viewable from menu item
    print(msg);
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

int timeZoneAbbreviationToOffset(String abbreviation)
{
  switch (abbreviation)
  {
    case "AMST":
      return -3;
    case "AMT":
      return -4;
    case "CDT":
      return -5;
    case "CEST":
      return 2;
    case "CET":
      return 1;
    case "CST":
      return -6;
    case "EDT":
      return -4;
    case "EST":
      return -5;
    case "JST":
      return 9;
    case "MDT":
      return -6;
    case "MST":
      return -7;
    case "PDT":
      return -7;
    case "PST":
      return -8;
    case "WEST":
      return 1;
    default:
      return 0;
  }
}

//*************************************************************************************************

DateTime stringToDateTimeUTC(String input)
{
  // DateFormat doesn't have the Z and zzz format specifiers implemented yet, so we don't have full support for timezones.
  // The following is kinda customized for the podcasts I listen to. And I don't think it will handle daylight savings time.
  
  // some examples:
  // Fri, 30 May 2025 20:24:00 -0000
  // Tue, 03 Jun 2025 21:00:05 PDT
  // Thu, 22 May 2025 15:43:21 +0000
  // Mon, 19 May 2025 12:00:00 -0800
  // Fri, 29 Sep 2023 19:00:00 GMT

  try
  {
    DateTime dateUTC = DateFormat("E, dd MMM yyyy HH:mm:ss").parse(input, true);

    if (input.length > 25)
    {
      String timezone = input.substring(input.lastIndexOf(" ") + 1);
      
      if (timezone[0] == "+" || timezone[0] == "-")
      {
        // it has the format -0800 or +0000
        int offsetHours = int.parse(timezone) ~/ 100;
        dateUTC = dateUTC.subtract(Duration(hours: offsetHours));
      }
      else
      {
        int offsetHours = timeZoneAbbreviationToOffset(timezone);
        dateUTC = dateUTC.subtract(Duration(hours: offsetHours));
      }
    }

    return dateUTC;
  }
  catch (err)
  {
    logDebugMsg(err.toString());
    // default date will be 1970
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

//*************************************************************************************************

String dateTimeUTCToStringUTC(DateTime input)
{
  // going to a String we will always assume UTC so there is no timezone info at the end
  return DateFormat("E, dd MMM yyyy HH:mm:ss").format(input);
}

//*************************************************************************************************

String dateTimeUTCToPrettyPrint(DateTime input)
{
  DateTime dateLocal = input.toLocal();
  DateTime now = DateTime.now();
  Duration diff = now.difference(dateLocal); // diff = now - dateLocal

  if (diff.inMinutes < 60)
  {
    // this will also handle negative time differences
    return "just now";
  }
  else if (diff.inHours == 1)
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
  else if (now.year == dateLocal.year)
  {
    return DateFormat("MMM d").format(dateLocal);
  }
  else
  {
    return DateFormat("MMM d, yyyy").format(dateLocal);
  }
}

//*************************************************************************************************

bool isExpired(DateTime localCacheTime, DateTime remoteTime)
{
  return remoteTime.isAfter(localCacheTime);
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

Future<String> getLocalPath() async
{
  // if this doesn't work on Android try android.permission.READ_EXTERNAL_STORAGE
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
