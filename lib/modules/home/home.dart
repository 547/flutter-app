import 'package:bbmusic/modules/open_music_order/list_view.dart';
import 'package:flutter/material.dart';
import 'package:bbmusic/modules/music_order/list.dart';
import 'package:bbmusic/modules/player/player.dart';
import 'package:bbmusic/modules/search/search.dart';
import 'package:bbmusic/modules/setting/setting.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<Widget> buildAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return SizedBox(
      height: 60,
      child: Center(
        child: Text(
          "版本号: ${packageInfo.version}",
          style: const TextStyle(
            color: Colors.black38,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    buildAppVersion();
    return Scaffold(
      appBar: AppBar(
        title: const Text("哔哔音乐"),
        centerTitle: true,
      ),
      floatingActionButton: const PlayerView(),
      body: Container(
        padding: const EdgeInsets.only(bottom: 100),
        child: ListView(
          children: [
            _ItemCard(
              icon: Icons.search,
              title: '搜索',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const SearchView();
                    },
                  ),
                );
              },
            ),
            _ItemCard(
              icon: Icons.diversity_2,
              title: '广场',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const OpenMusicOrderListView();
                    },
                  ),
                );
              },
            ),
            _ItemCard(
              icon: Icons.person_4_outlined,
              title: '我的歌单',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const UserMusicOrderView();
                    },
                  ),
                );
              },
            ),
            // _ItemCard(
            //   icon: Icons.download,
            //   title: '下载管理',
            //   onTap: () {
            //     Navigator.of(context).push(
            //       MaterialPageRoute(
            //         builder: (BuildContext context) {
            //           return const DownloadListView();
            //         },
            //       ),
            //     );
            //   },
            // ),
            _ItemCard(
              icon: Icons.settings,
              title: '设置',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const SettingView();
                    },
                  ),
                );
              },
            ),
            FutureBuilder(
              future: buildAppVersion(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return snapshot.data!;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Function? onTap;

  const _ItemCard({
    super.key,
    this.onTap,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(left: 30, right: 30, top: 20),
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!();
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: MediaQuery.of(context).size.width - 30,
          padding:
              const EdgeInsets.only(top: 30, bottom: 30, left: 20, right: 20),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 15),
              Text(
                title,
                style: const TextStyle(fontSize: 20),
              )
            ],
          ),
        ),
      ),
    );
  }
}
