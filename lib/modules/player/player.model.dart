import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/modules/player/player.const.dart';
import 'package:flutter_app/origin_sdk/origin_types.dart';
import 'package:flutter_app/origin_sdk/service.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKeyCurrent = 'player_current';
const _storageKeyPlayerList = 'player_player_list';
const _storageKeyPlayerMode = 'player_player_mode';
const _storageKeyEnabledRandom = 'player_enabled_random';
const _storageKeyPosition = 'player_position';

class PlayerModel extends ChangeNotifier {
  // 计时器
  Timer? _timer;
  // 播放器实例
  final audio = AudioPlayer();
  // 播放器播放列表
  final _audioPlayList = ConcatenatingAudioSource(
    // 在播放完成之前开始加载下一个项目
    useLazyPreparation: false,
    shuffleOrder: DefaultShuffleOrder(),
    children: [],
  );
  // 当前歌曲
  MusicItem? get current {
    if (audio.currentIndex != null) {
      final source = _audioPlayList.children[audio.currentIndex!];
      if (source is BBMusicSource) {
        return source.music;
      }
    }
    return null;
  }

  // 歌曲是否加载
  bool isLoading = false;
  // 播放列表
  List<MusicItem> get playerList {
    final List<MusicItem> list = [];
    for (final item in _audioPlayList.children) {
      if (item is BBMusicSource) {
        list.add(item.music);
      }
    }
    return list;
  }

  // 播放状态
  bool get isPlaying {
    return audio.playing;
  }

  // 播放模式
  PlayerMode playerMode = PlayerMode.listLoop;
  // 是否开启随机播放
  bool get enabledRandom {
    return audio.shuffleModeEnabled;
  }

  set enabledRandom(bool value) {
    audio.setShuffleModeEnabled(value);
  }

  init() {
    _initLocalStorage();
    audio.playerStateStream.listen((state) {
      // print("====== START =======");
      // print(state);
      // print(current?.name);
      // print("====== END ========");
      if (state.playing) {
        notifyListeners();
      } else {
        notifyListeners();
      }
      if (state.processingState == ProcessingState.loading) {
        isLoading = true;
        notifyListeners();
      }
      if (state.processingState == ProcessingState.ready) {
        // closeLoading();
        isLoading = false;
        notifyListeners();
      }
      // if (state.processingState == ProcessingState.completed) {
      //   // endNext();
      // }
    });
    audio.currentIndexStream.listen((index) {
      if (index != null) {
        print(current?.name);
        _updateLocalStorage();
      }
      notifyListeners();
    });

    // 记住播放进度
    var t = DateTime.now();
    audio.positionStream.listen((event) {
      var n = DateTime.now();
      if (t.add(const Duration(seconds: 5)).isBefore(n)) {
        _savePlayerPosition();
        t = n;
      }
    });
  }

  // 播放
  Future<void> play({MusicItem? music}) async {
    if (music != null) {
      // 判断播放列表是否已存在
      if (!_musicIsInPlayerList(music)) {
        // 不存在，添加到播放列表
        await addPlayerList([music]);
      }

      if (_musicIsCurrent(music) && audio.playing) {
        await audio.pause();
      } else {
        await _paly(music: music);
      }
    } else {
      if (current != null && audio.playing) {
        // 播放中暂停
        await audio.pause();
      } else {
        await _paly();
      }
    }
    notifyListeners();
  }

  // 暂停
  Future<void> pause() async {
    await audio.pause();
    notifyListeners();
  }

  // 上一首
  Future<void> prev() async {
    await audio.seekToPrevious();
    _updateLocalStorage();
  }

  // 下一首
  Future<void> next() async {
    await audio.seekToNext();
    _updateLocalStorage();
  }

  // 切换随机
  Future<bool> toggleRandom({bool? enabled}) async {
    if (enabled != null) {
      enabledRandom = enabled;
    } else {
      enabledRandom = !enabledRandom;
    }
    _updateLocalStorage();
    notifyListeners();
    return enabledRandom;
  }

  // 切换播放模式
  Future<void> togglePlayerMode(PlayerMode? mode) async {
    if (mode != null) {
      playerMode = mode;
    } else {
      const l = [
        PlayerMode.signalLoop,
        PlayerMode.listLoop,
        PlayerMode.listOrder,
      ];
      int index = l.indexWhere((p) => playerMode == p);

      if (index == l.length - 1) {
        playerMode = l[0];
      } else {
        playerMode = l[index + 1];
      }
    }

    if (mode == PlayerMode.signalLoop) {
      await audio.setLoopMode(LoopMode.one);
    }
    if (mode == PlayerMode.listLoop) {
      await audio.setLoopMode(LoopMode.all);
    }
    if (mode == PlayerMode.listOrder) {
      await audio.setLoopMode(LoopMode.off);
    }
    _updateLocalStorage();
    notifyListeners();
  }

  // 添加到播放列表中
  Future<void> addPlayerList(List<MusicItem> musics) async {
    await removePlayerList(musics);
    final list = musics.map((music) => BBMusicSource(music: music)).toList();
    await _audioPlayList.addAll(list);
    _updateLocalStorage();
    notifyListeners();
  }

  // 在播放列表中移除
  Future<void> removePlayerList(List<MusicItem> musics) async {
    for (final item in _audioPlayList.children) {
      if (item is BBMusicSource) {
        final index = _audioPlayList.children.indexOf(item);
        // 移除已存在的
        if (musics.where((m) => _musicEqPlayerMusic(m, item)).isNotEmpty) {
          await _audioPlayList.removeAt(index);
        }
      }
    }
    _updateLocalStorage();
    notifyListeners();
  }

  // 清空播放列表
  Future<void> clearPlayerList() async {
    print('clearPlayerList');
    _audioPlayList.clear();
    _updateLocalStorage();
    notifyListeners();
  }

  // 判断歌曲是否和播放的歌曲相同
  bool _musicEqPlayerMusic(MusicItem music, BBMusicSource playerMusic) {
    return music.id == playerMusic.music.id &&
        music.origin == playerMusic.music.origin;
  }

  // 歌曲是否存在于播放列表中
  bool _musicIsInPlayerList(MusicItem music) {
    for (final item in _audioPlayList.children) {
      if (item is BBMusicSource) {
        if (_musicEqPlayerMusic(music, item)) {
          return true;
        }
      }
    }
    return false;
  }

  // 歌曲是否存在于播放列表中
  bool _musicIsCurrent(MusicItem item) {
    final cur = audio.audioSource;
    if (cur != null && cur is BBMusicSource) {
      return cur.music.id == item.id && cur.music.origin == item.origin;
    }

    return false;
  }

  // 播放
  Future<int> _paly({MusicItem? music, bool? isPlay = true}) async {
    int ind = -1;
    if (music != null) {
      int index = _audioPlayList.children.indexWhere((c) {
        if (c is BBMusicSource) {
          return _musicEqPlayerMusic(music, c);
        }
        return false;
      });
      if (index > -1) {
        await audio.seek(Duration.zero, index: index);
      }
      ind = index;
    }

    if (isPlay == true) {
      await audio.play();
    }
    return ind;
  }

  // 保存播放进度
  _savePlayerPosition() async {
    final localStorage = await SharedPreferences.getInstance();
    final value = audio.position.inMilliseconds;
    localStorage.setInt(_storageKeyPosition, value);
  }

  // 更新缓存
  _updateLocalStorage() {
    _timer?.cancel();
    _timer = Timer(const Duration(microseconds: 500), () async {
      final localStorage = await SharedPreferences.getInstance();
      // 当前播放的歌曲
      localStorage.setString(
        _storageKeyCurrent,
        current != null ? jsonEncode(current) : "",
      );
      // 播放模式
      localStorage.setString(
        _storageKeyPlayerMode,
        playerMode.value.toString(),
      );
      // 是否开启随机播放
      localStorage.setBool(_storageKeyEnabledRandom, enabledRandom);
      // 播放列表
      List<MusicItem> l = [];
      for (var child in _audioPlayList.children) {
        if (child is BBMusicSource) {
          l.add(child.music);
        }
      }
      localStorage.setStringList(
        _storageKeyPlayerList,
        l.map((e) => jsonEncode(e)).toList(),
      );
    });
  }

  // 读取缓存
  _initLocalStorage() async {
    print('_initLocalStorage');
    final localStorage = await SharedPreferences.getInstance();
    // 播放模式
    String? m = localStorage.getString(_storageKeyPlayerMode);
    if (m != null && m.isNotEmpty && m != '2') {
      playerMode = PlayerMode.getByValue(int.parse(m));
      togglePlayerMode(playerMode);
    }

    // 是否开启随机播放
    enabledRandom = localStorage.getBool(_storageKeyEnabledRandom) ?? false;

    // 播放列表
    List<String>? pl = localStorage.getStringList(_storageKeyPlayerList);
    print('pl: ${pl?.length}');

    if (_audioPlayList.children.isNotEmpty) {
      _audioPlayList.children.clear();
    }
    if (pl != null && pl.isNotEmpty) {
      for (var e in pl) {
        var data = jsonDecode(e) as Map<String, dynamic>;
        final music = MusicItem(
          id: data['id'],
          name: data['name'],
          cover: data['cover'],
          author: data['author'],
          duration: data['duration'],
          origin: OriginType.getByValue(data['origin']),
        );
        await _audioPlayList.add(
          BBMusicSource(music: music),
        );
      }
    }
    if (_audioPlayList.children.isNotEmpty) {
      await audio.setAudioSource(
        _audioPlayList,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
    }

    // 当前播放的歌曲
    String? c = localStorage.getString(_storageKeyCurrent);
    if (c != null && c.isNotEmpty) {
      var data = jsonDecode(c) as Map<String, dynamic>;
      String id = data['id'];
      final music = MusicItem(
        id: id,
        name: data['name'],
        cover: data['cover'],
        author: data['author'],
        duration: data['duration'],
        origin: OriginType.getByValue(data['origin']),
      );
      print('cache: ${music.name}');
      await _paly(music: music, isPlay: false);
      final pos = localStorage.getInt(_storageKeyPosition);
      print('pos = $pos');
      // audio.seek(Duration(milliseconds: pos ?? 0));
    }

    notifyListeners();
  }
}

class BBMusicSource extends StreamAudioSource {
  final List<int> _bytes = [];
  int _sourceLength = 0;
  String _contentType = 'video/mp4';
  final MusicItem music;
  bool _isInit = false;
  @override
  MediaItem get tag {
    return MediaItem(
      id: music.id,
      title: music.name,
      artUri: Uri.parse(music.cover),
    );
  }

  static Future<http.StreamedResponse> getMusicStream(
    MusicItem music,
    Function(List<int> data) callback,
  ) {
    final completer = Completer<http.StreamedResponse>();

    service.getMusicUrl(music.id).then((musicUrl) {
      var request = http.Request('GET', Uri.parse(musicUrl.url));
      request.headers.addAll(musicUrl.headers ?? {});
      http.Client client = http.Client();
      // StreamSubscription videoStream;
      client.send(request).then((response) {
        var isStart = false;
        response.stream.listen((List<int> data) {
          callback(data);
          if (!isStart) {
            completer.complete(response);
            isStart = true;
          }
          // TODO 后续加个缓存方法
        });
      }).catchError((error) {
        completer.completeError(error);
      });
    }).catchError((error) {
      completer.completeError(error);
    });
    return completer.future;
  }

  BBMusicSource({required this.music});

  _init() async {
    if (_isInit) return;
    var resp = await BBMusicSource.getMusicStream(music, (List<int> data) {
      _bytes.addAll(data);
    });
    _sourceLength = resp.contentLength ?? 0;
    _contentType = resp.headers['content-type'] ?? 'video/mp4';
    _isInit = true;
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    await _init();
    start ??= 0;
    // 轮询 _bytes 的长度, 等待 _bytes 有足够的数据
    while (_bytes.length < start) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    end ??= _bytes.length;

    return StreamAudioResponse(
      sourceLength: _sourceLength,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: _contentType,
    );
  }
}
