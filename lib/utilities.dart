import 'dart:io';

import 'package:flutter/foundation.dart';

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
