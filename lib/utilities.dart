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

  if (diff.inDays == 1)
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

Future<void> saveToFile(String filename, Uint8List bytes) async
{
  File fd = await File(filename).create(recursive: true);
  await fd.writeAsBytes(bytes);
}

//*************************************************************************************************

Future<String> readFile(String filename) async
{
  File fd = File(filename);
  return await fd.readAsString();
}
