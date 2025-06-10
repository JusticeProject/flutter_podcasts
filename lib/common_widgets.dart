import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'episode_page.dart';
import 'data_structures.dart';
import 'data_model.dart';
import 'utilities.dart';

//*************************************************************************************************

class DownloadButton extends StatelessWidget
{
  const DownloadButton({super.key, required this.episode, required this.largeIcon});

  final Episode episode;
  final bool largeIcon;

  //*******************************************************

  void _onDownloadEpisode(DataModel dataModel) async
  {
    logDebugMsg("download requested for ${episode.title}");
    try
    {
      await dataModel.fetchEpisode(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  void _onRemoveDownloadedEpisode(DataModel dataModel) async
  {
    logDebugMsg("removing episode ${episode.title}");
    try
    {
      await dataModel.removeEpisode(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    DataModel dataModel = context.watch<DataModel>();

    if (episode.isDownloading && episode.downloadProgress == 0.0)
    {
      // show a grey spinning progress indicator until we have some progress to show
      return IconButton(
        icon: CircularProgressIndicator(color: Theme.of(context).disabledColor),
        iconSize: largeIcon ? 60 : null,
        // I don't like having to specify exact sizes below in the BoxConstraints, but the progress indicator and Icons.download
        // were not the same size, so when it switched between the two the layout shifted up/down
        constraints: largeIcon ? null : BoxConstraints(minWidth: 40, minHeight: 40, maxWidth: 40, maxHeight: 40),
        onPressed: () {},
      );
    }
    else if (episode.isDownloading && episode.downloadProgress > 0)
    {
      // show download progress
      return IconButton(
        icon: CircularProgressIndicator(value: episode.downloadProgress),
        iconSize: largeIcon ? 60 : null,
        constraints: largeIcon ? null : BoxConstraints(minWidth: 40, minHeight: 40, maxWidth: 40, maxHeight: 40),
        onPressed: () {}
      );
    }
    else if (episode.filename.isEmpty)
    {
      // enable download button
      return IconButton(
        icon: Icon(Icons.download),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onDownloadEpisode(dataModel)
      );
    }
    else
    {
      // show download complete button, can be tapped to remove the download
      return IconButton(
        icon: Icon(Icons.download_done, color: Theme.of(context).colorScheme.primary),
        iconSize: largeIcon ? 60 : null,
        onPressed: () {
          showDialog(context: context, builder: (context) {
            return AlertDialog(
              title: Text("Remove downloaded episode?"),
              actions: [
                TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
                TextButton(child: const Text('Remove'), onPressed: () {
                    _onRemoveDownloadedEpisode(dataModel);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
        },
        
      );
    }
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class PlayButton extends StatelessWidget
{
  const PlayButton({super.key, required this.episode, required this.largeIcon});

  final Episode episode;
  final bool largeIcon;

  //*******************************************************

  void _onPlayEpisode(DataModel dataModel) async
  {
    try
    {
      await dataModel.playEpisode(episode);
      dataModel.showMiniPlayer(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  void _onPauseEpisode(DataModel dataModel) async
  {
    try
    {
      await dataModel.pauseEpisode(episode);
    }
    catch (err)
    {
      dataModel.showMessageToUser(err.toString());
    }
  }

  //*******************************************************

  @override
  Widget build(BuildContext context)
  {
    DataModel dataModel = context.watch<DataModel>();

    if (episode.filename.isEmpty)
    {
      // no downloaded file and it's obviously not playing right now
      return IconButton(
        icon: Icon(Icons.play_arrow_outlined, color: Theme.of(context).disabledColor),
        iconSize: largeIcon ? 60 : null,
        onPressed: () {}
      );
    }
    else if (episode.isPlaying)
    {
      // it's playing
      return IconButton(
        icon: Icon(Icons.pause),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onPauseEpisode(dataModel),
      );
    }
    else
    {
      // we have the file downloaded but it's not playing right now
      return IconButton(
        icon: Icon(Icons.play_arrow),
        iconSize: largeIcon ? 60 : null,
        onPressed: () => _onPlayEpisode(dataModel)
      );
    }
  }
}

//*************************************************************************************************
//*************************************************************************************************
//*************************************************************************************************

class MiniPlayer extends StatelessWidget
{
  const MiniPlayer({super.key, required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EpisodePage(episode: episode))),
      child: Container(
        color: Colors.grey[850],
        padding: EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 40, height: 40, child: episode.albumArt),
            SizedBox(width: 10),
            Expanded(child: 
              Text(episode.title, maxLines: 2, overflow: TextOverflow.fade, style: TextStyle(fontWeight: FontWeight.bold))
            ),
            PlayButton(episode: episode, largeIcon: false)
        ]),
      ),
    );
  }
}
