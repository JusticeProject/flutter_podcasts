import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'utilities.dart';
import 'data_structures.dart';

//*************************************************************************************************

class EpisodePage extends StatelessWidget
{
  const EpisodePage({super.key, required this.episode});

  final Episode episode;

  //*******************************************************

  void _onLinkTapped(String? url) async
  {
    if (url != null)
    {
      logDebugMsg(url);

      try
      {
        final Uri uri = Uri.parse(url);
        bool canLaunch = await canLaunchUrl(uri);
        if (canLaunch)
        {
          logDebugMsg("can launch");
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
        else
        {
          logDebugMsg("can't launch");
        }
      }
      catch (err)
      {
        logDebugMsg("caught exception: ${err.toString()}");
      }
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(episode.title, style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                SizedBox(height: 10),
                Html(data: episode.description, onLinkTap: (url, attributes, element) => _onLinkTapped(url))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
