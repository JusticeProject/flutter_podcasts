import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import 'data_structures.dart';
import 'utilities.dart';

//*************************************************************************************************

final int MAX_NUM_EPISODES = 10;

//*************************************************************************************************

String getFeedPubDate(XmlDocument xml)
{
  // first element is <rss> then second element is <channel>
  XmlElement? channel = xml.firstElementChild?.firstElementChild;
  XmlElement? pubDate = channel?.getElement("pubDate");
  if (pubDate != null)
  {
    return pubDate.innerText;
  }

  // if there is no top level pubDate then try the first item
  XmlElement? item = channel?.getElement("item");
  if (item != null)
  {
    XmlElement? pubDate = item.getElement("pubDate");
    if (pubDate != null)
    {
      return pubDate.innerText;
    }
  }

  throw Exception("could not find pubDate in xml");
}

//*************************************************************************************************

String getAlbumArtURL(XmlDocument xml)
{
  // first element is <rss> then second element is <channel>
  XmlElement? channel = xml.firstElementChild?.firstElementChild;

  // try the <image> element first
  XmlElement? image = channel?.getElement("image");
  XmlElement? url = image?.getElement("url");
  if (url != null)
  {
    return url.innerText;
  }
  
  // next try the <itunes:image> element
  image = channel?.getElement("itunes:image");
  if (image != null)
  {
    return image.attributes.first.value;
  }

  throw Exception("could not find image url in xml");
}

//*************************************************************************************************

String getFeedTitle(XmlDocument xml)
{
  // this is a slower version of getting the channel element
  //XmlElement? rss = xml.getElement("rss");
  //XmlElement? channel = rss?.getElement("channel");

  // this is a faster version of getting the channel element
  XmlElement? channel = xml.firstElementChild?.firstElementChild;
  XmlElement? title = channel?.getElement("title");
  if (title != null)
  {
    return title.innerText;  
  }

  throw Exception("could not find title in xml");
}

//*************************************************************************************************

String getFeedAuthor(XmlDocument xml)
{
  // first element is <rss> then second element is <channel>
  XmlElement? channel = xml.firstElementChild?.firstElementChild;
  XmlElement? author = channel?.getElement("itunes:author");
  if (author != null)
  {
    return author.innerText;
  }

  throw Exception("could not find author in xml");
}

//*************************************************************************************************

String getFeedDescription(XmlDocument xml)
{
  // first element is <rss> then second element is <channel>
  XmlElement? channel = xml.firstElementChild?.firstElementChild;
  XmlElement? description = channel?.getElement("description");
  if (description != null)
  {
    return removeHtmlTags(description.innerText);
  }

  throw Exception("could not find description in xml");
}

//*************************************************************************************************

Future<List<Episode>> getFeedEpisodes(XmlDocument xml, String localDir, Image albumArt) async
{
  XmlElement? channel = xml.firstElementChild?.firstElementChild;
  if (channel != null)
  {
    var items = channel.findElements("item");
    List<Episode> episodes = [];
    for (var item in items)
    {
      String guid = getGuidOfItem(item);
      String combinedPath = combinePaths(localDir, guid);
      bool localFileExists = await File(combinedPath).exists();
      String filename = localFileExists ? guid : "";
      String url = getUrlOfItem(item);
      XmlElement? title = item.getElement("title");
      XmlElement? description = item.getElement("description");
      XmlElement? pubDate = item.getElement("pubDate");
      if (guid.isNotEmpty && url.isNotEmpty && title != null && description != null && pubDate != null)
      {
        String descriptionNoHtml = removeHtmlTags(description.innerText);
        DateTime dateUTC = stringToDateTimeUTC(pubDate.innerText);
        episodes.add(Episode(
          localDir: localDir,
          filename: filename,
          guid: guid,
          url: url,
          title: title.innerText, 
          description: description.innerText, 
          descriptionNoHtml: descriptionNoHtml,
          albumArt: albumArt,
          datePublishedUTC: dateUTC)
        );
      }

      // some feeds have ALL the episodes but we are limiting it to MAX_NUM_EPISODES
      if (episodes.length >= MAX_NUM_EPISODES)
      {
        break;
      }
    }

    return episodes;
  }

  // nothing found, so no episodes
  return <Episode>[];
}

//*************************************************************************************************

String getGuidOfItem(XmlElement item)
{
  XmlElement? guid = item.getElement("guid");
  if (guid == null)
  {
    return "";
  }

  // some examples:
  // <guid isPermaLink="false">b762491f-5683-41d1-a6c4-0b81ac6800c2</guid>
  // <guid isPermaLink="false">https://pdst.fm/e/pscrb.fm/rss/p/cdn.twit.tv/audio/twig/twig0822/twig0822.mp3</guid>
  // <guid isPermaLink="false">aadf1025-c84e-4553-aaf0-034a21f73a21</guid>
  // <guid isPermaLink="false"><![CDATA[926dde42-3a2c-11ef-8844-a758818393e3]]></guid>

  String innerText = guid.innerText;
  if (!innerText.contains("/"))
  {
    return innerText;
  }

  // from the example above this will produce twig0822.mp3
  return innerText.substring(innerText.lastIndexOf("/") + 1);
}

//*************************************************************************************************

String getUrlOfItem(XmlElement item)
{
  XmlElement? enclosure = item.getElement("enclosure");
  if (enclosure == null)
  {
    return "";
  }

  // some examples:
  // <enclosure url="https://pdst.fm/e/pscrb.fm/rss/p/cdn.twit.tv/libsyn/twig_822/5b6c1516-7338-4acd-91f1-08131542eeec/R1_twig0822.mp3" length="166756633" type="audio/mpeg"/>
  // <enclosure url="https://www.podtrac.com/pts/redirect.mp3/pdst.fm/e/chrt.fm/track/FGADCC/pscrb.fm/rss/p/tracking.swap.fm/track/bwUd3PHC9DH3VTlBXDTt/traffic.megaphone.fm/SBP4198775748.mp3?updated=1748636657" length="0" type="audio/mpeg"/>
  // <enclosure length="65027664" type="audio/mpeg" url="https://afp-9384.calisto.simplecastaudio.com/22107083-afe9-4e16-a465-226032982b33/episodes/3fd8ce34-2aab-4d36-b9f2-cc4d9d76e7b3/audio/128/default.mp3?aid=rss_feed&amp;awCollectionId=22107083-afe9-4e16-a465-226032982b33&amp;awEpisodeId=3fd8ce34-2aab-4d36-b9f2-cc4d9d76e7b3&amp;feed=6WD3bDj7"/>
  
  String? url = enclosure.getAttribute("url");
  return url ?? "";
}

//*************************************************************************************************

String removeHtmlTags(String input)
{
  // . means wildcard
  // dotAll means the wildcard . will match all characters including line terminators
  // *? means non-greedy version of * (* means 0 or more)
  // .*? means 0 or more of any char, it will match the least amount of chars
  RegExp re = RegExp(r"<.*?>", dotAll: true);
  String result = input.replaceAll(re, "");
  result = result.replaceAll("&amp;", "&");
  return result.trim();
}
