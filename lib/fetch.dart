import 'package:http/http.dart' as http;

//*************************************************************************************************

Future<String> fetchRSS(String url) async
{
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode == 200)
  {
    return resp.body;
  }
  else
  {
    throw Exception("could not fetch url $url");
  }
}

//*************************************************************************************************
