import 'package:flutter/material.dart';

//*************************************************************************************************

class Menu extends StatelessWidget
{
  const Menu({super.key});

  @override
  Widget build(BuildContext context)
  {
    return PopupMenuButton<String>(
      onSelected: (String item) {
        if (item == 'About') {
          showAboutDialog(
            context: context,
            applicationName: 'Podcasts',
            applicationVersion: '1.0',
            applicationIcon: const Icon(Icons.info),
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 15),
                child: Text('Made with flutter.'),
              ),
            ],
          );
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          const PopupMenuItem<String>(
            value: 'About',
            child: Text('About'),
          ),
        ];
      },
    );
  }
}
