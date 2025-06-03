import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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

DateTime parseDateTime(String input)
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
