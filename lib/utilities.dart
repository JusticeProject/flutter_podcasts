import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

//*************************************************************************************************

logDebugMsg(String msg)
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
  logDebugMsg(dir1.path);
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

Future<void> saveFile(String filename, List<int> data) async
{
  String localDir = await getLocalPath();
  String fullPath = localDir + Platform.pathSeparator + filename;
  logDebugMsg("Writing ${data.length} bytes to $fullPath");
  File fd = File(fullPath);
  await fd.writeAsBytes(data);
}
