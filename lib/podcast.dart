import 'package:flutter/material.dart';

class Podcast
{
  Podcast(this.localDir, this.title, this.albumArt);
  
  final String localDir;
  final String title;
  final Image albumArt;
}
