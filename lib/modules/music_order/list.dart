import 'package:bbmusic/modules/music_order/edit_order.dart';
import 'package:bbmusic/modules/setting/music_order_origin/mode.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bbmusic/components/sheet/bottom_sheet.dart';
import 'package:bbmusic/modules/music_order/detail.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:provider/provider.dart';

typedef OnItemHandler = void Function(
  UserMusicOrderOriginItem umo,
  MusicOrderItem data,
);

class UserMusicOrderView extends StatelessWidget {
  final MusicOrderItem? musicOrder;
  const UserMusicOrderView({super.key, this.musicOrder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("我的歌单"),
      ),
      body: UserMusicOrderList(musicOrder: musicOrder),
    );
  }
}

class UserMusicOrderList extends StatelessWidget {
  final MusicOrderItem? musicOrder;
  // 是否为适用于收藏模式的样式
  final bool? collectModalStyle;
  // 点击每个选项时的回调
  final OnItemHandler? onItemTap;
  const UserMusicOrderList({
    super.key,
    this.collectModalStyle,
    this.onItemTap,
    this.musicOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicOrderOriginSettingModel>(
      builder: (context, store, child) {
        return ListView(
          children: [
            ...store.userMusicOrderList.map((e) {
              return _MusicOrderListItemView(
                musicOrder: musicOrder,
                umo: e,
                collectModalStyle: collectModalStyle,
                onItemTap: onItemTap,
              );
            }),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}

class _MusicOrderListItemView extends StatefulWidget {
  final MusicOrderItem? musicOrder;
  final UserMusicOrderOriginItem umo;
  // 是否为适用于收藏模式的样式
  final bool? collectModalStyle;
  // 点击每个选项时的回调
  final OnItemHandler? onItemTap;

  const _MusicOrderListItemView({
    super.key,
    this.collectModalStyle,
    this.onItemTap,
    this.musicOrder,
    required this.umo,
  });

  @override
  _MusicOrderListItemViewState createState() => _MusicOrderListItemViewState();
}

class _MusicOrderListItemViewState extends State<_MusicOrderListItemView> {
  get _canUse => widget.umo.service.canUse();

  static const _loading = Center(
    child: SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(),
    ),
  );

  _formItemHandler(MusicOrderItem? data) {
    if (!widget.umo.service.canUse()) {
      BotToast.showSimpleNotification(
        title: "歌单源目前无法使用,请先完善配置",
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      return EditMusicOrder(
        service: widget.umo.service,
        data: data,
        originSettingId: widget.umo.id,
      );
    }));
  }

  @override
  void initState() {
    super.initState();
  }

  // 跳转歌单详情
  _gotoMusicOrderDetail(MusicOrderItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (BuildContext context) {
        return MusicOrderDetail(
          data: item,
          umoService: widget.umo.service,
          originSettingId: widget.umo.id,
        );
      },
    ));
  }

  // 歌单更多操作
  _moreHandler(MusicOrderItem item) {
    if (widget.collectModalStyle == true) return;
    openBottomSheet(context, [
      SheetItem(
        title: const Text('查看歌单'),
        onPressed: () {
          _gotoMusicOrderDetail(item);
        },
      ),
      SheetItem(
        title: const Text('编辑歌单'),
        onPressed: () {
          _formItemHandler(item);
        },
      ),
      SheetItem(
        title: const Text('删除歌单'),
        onPressed: () {
          widget.umo.service.delete(item).then((value) {
            BotToast.showSimpleNotification(title: "已删除");
            Provider.of<MusicOrderOriginSettingModel>(
              context,
              listen: false,
            ).loadSignal(widget.umo.id);
          });
        },
      ),
    ]);
  }

  Widget _cardBuild(List<Widget> children) {
    return SizedBox(
      height: 60,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget _errorBuild() {
    return _cardBuild([
      const Text('歌单源数据获取失败'),
      const SizedBox(height: 20),
      // TextButton(
      //     onPressed: () {
      //       // final settingWidget = widget.umo.service.configBuild();
      //       // if (settingWidget != null) {
      //       //   Navigator.of(context).push(
      //       //     MaterialPageRoute(
      //       //       builder: (context) {
      //       //         return settingWidget;
      //       //       },
      //       //     ),
      //       //   );
      //       // }
      //     },
      //     child: const Text('重试'))
    ]);
  }

  Widget _emptyBuild() {
    return _cardBuild([
      const Text('歌单源目前无法使用,请先完善配置'),
      // const SizedBox(height: 20),
      // TextButton(
      //   onPressed: () {
      //     // final settingWidget = widget.umo.service.configBuild();
      //     // if (settingWidget != null) {
      //     //   Navigator.of(context).push(
      //     //     MaterialPageRoute(
      //     //       builder: (context) {
      //     //         return settingWidget;
      //     //       },
      //     //     ),
      //     //   );
      //     // }
      //   },
      //   child: const Text('完善配置'),
      // )
    ]);
  }

  // 源名称与添加按钮
  Widget _headerBuild() {
    return Container(
      width: double.infinity,
      height: 50,
      color: Theme.of(context).hoverColor,
      padding: const EdgeInsets.only(
        left: 15,
        right: 15,
        top: 5,
        bottom: 5,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 点击刷新
          Row(
            children: [
              TextButton(
                child: Text(
                  widget.umo.service.cname,
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
                onPressed: () {
                  Provider.of<MusicOrderOriginSettingModel>(
                    context,
                    listen: false,
                  ).loadSignal(widget.umo.id);
                },
              ),
              const SizedBox(width: 10),
              Text(
                Provider.of<MusicOrderOriginSettingModel>(
                      context,
                      listen: false,
                    ).id2OriginInfo(widget.umo.id)?.subName ??
                    "",
                style: const TextStyle(fontSize: 14),
              )
            ],
          ),
          Visibility(
            visible: _canUse,
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _formItemHandler(widget.musicOrder);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 列表
  Widget _listBuild(List<MusicOrderItem> list) {
    if (!_canUse) _emptyBuild();
    return Column(
      children: [
        const SizedBox(height: 2),
        ...list.map((item) {
          return ListTile(
            onTap: () {
              if (widget.collectModalStyle == true) {
                if (widget.onItemTap != null) {
                  widget.onItemTap!(widget.umo, item);
                }
                return;
              }

              _gotoMusicOrderDetail(item);
            },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: item.cover != null && item.cover!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.cover!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      color: const Color.fromARGB(179, 209, 205, 205),
                      child: Center(
                        child: Text(item.name.substring(0, 1)),
                      ),
                    ),
            ),
            title: Text(item.name),
            subtitle: item.desc.isNotEmpty ? Text(item.desc) : null,
            minTileHeight: 60,
            trailing: widget.collectModalStyle == true
                ? null
                : InkWell(
                    borderRadius: BorderRadius.circular(4.0),
                    onTap: () {
                      _moreHandler(item);
                    },
                    child: const Icon(Icons.more_vert),
                  ),
            onLongPress: () {
              _moreHandler(item);
            },
          );
        }),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _container(double height, Widget child) {
    return Column(
      children: [
        _headerBuild(),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.umo.list,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.data != null) {
          final list = snap.data!;
          return _container(list.length * 70 + 70, _listBuild(list));
        }
        if (snap.hasError) {
          return _container(130, _errorBuild());
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return _container(
            130,
            _loading,
          );
        }
        return _container(130, Container());
      },
    );
  }
}
