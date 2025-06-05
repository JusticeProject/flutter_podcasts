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

DateTime stringToDateTimeUTC(String input)
{
  // TODO: need better timezone support, DateFormat doesn't have the Z and zzz format specifiers implemented yet.
  // The following is kinda customized for the podcasts I listen to. And I don't think it will handle daylight savings time.
  try
  {
    DateTime dateUTC = DateFormat("E, dd MMM yyyy HH:mm:ss").parse(input, true);

    if (input.length == 31)
    {
      // it has the format -0800 or +0000
      int offsetHours = int.parse(input.substring(26, 29));
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

    return dateUTC;
  }
  catch (err)
  {
    logDebugMsg(err.toString());
    rethrow;
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

  // TODO: add x minutes ago? or return the string "now"?
  // what if the difference is negative?

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
