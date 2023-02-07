import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'main.dart';

final mediaStore = MediaStore();

class VideoViewPage extends StatefulWidget {
  const VideoViewPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _VideoViewPageState();
  }
}

class _VideoViewPageState extends State<VideoViewPage> {
  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return Scaffold(
      appBar: AppBar(
        title: const Text('库'),
      ),
      body: const VideoList(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class VideoList extends StatefulWidget {
  const VideoList({super.key});

  @override
  State<StatefulWidget> createState() {
    return _VideoListState();
  }
}

getFileSize(String file, int decimals) {
  try {
    int bytes = File(file).lengthSync();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "K", "M", "G", "T", "P", "E", "Z", "Y"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  } catch (e) {
    return 0;
  }
}

class _VideoListState extends State<VideoList> {
  @override
  void dispose() {
    for (final kid in kids) {
      if (kid.deleted) {
        try {
          if (File(kid.file).existsSync()) {
            File(kid.file).deleteSync();
          }
        } catch (e) {
          Clipboard.setData(ClipboardData(text: e.toString()));
        }
      }
    }
    super.dispose();
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  final List<VideoCard> kids = <VideoCard>[];
  final List<bool> kidDeleled = <bool>[];

  @override
  Widget build(BuildContext context) {
    final dir = Directory(dcimPath);
    if (dir.existsSync()) {
      int idx = 0;
      final fileList = Directory(dcimPath).listSync().toList()
        ..sort(
            (l, r) => l.statSync().modified.compareTo(r.statSync().modified));
      final filePathList = fileList.map((f) => f.path).toList();
      for (final file in filePathList.reversed) {
        if (!file.endsWith('mp4') && !file.endsWith('jpg')) {
          continue;
        }
        kidDeleled.add(false);
        kids.add(
          VideoCard(idx, file, showInSnackBar),
        );
        idx++;
      }
    }
    return ListView(
      children: kids,
    );
  }
}

class VideoCard extends StatefulWidget {
  late final String file;
  late final Function showInSnackBar;
  late final int idx;
  bool deleted = false;

  VideoCard(int i, String f, Function ssb, {super.key}) {
    file = f;
    idx = i;
    showInSnackBar = ssb;
  }

  @override
  State<StatefulWidget> createState() => VideoCardState();
}

class VideoCardState extends State<VideoCard> {
  late bool disabled;
  @override
  Widget build(BuildContext context) {
    disabled = widget.deleted;
    return Card(
      color: widget.deleted ? Colors.grey : Colors.white,
      child: Column(
        children: <Widget>[
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading:
                Icon(widget.file.endsWith('mp4') ? Icons.movie : Icons.image),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.file.split('/').last.split('.').first}'
                    ' (${getFileSize(widget.file, 1)})'),
                disabled
                    ? IconButton(
                        tooltip: '撤销',
                        onPressed: () {
                          setState(() {
                            disabled = false;
                            widget.deleted = false;
                          });
                        },
                        icon: const Icon(Icons.undo))
                    : PopupMenuButton(
                        itemBuilder: (context) {
                          return [
                            const PopupMenuItem<int>(
                                value: 1, child: Text("分享")),
                            const PopupMenuItem<int>(
                                value: 2, child: Text("打开")),
                            const PopupMenuItem<int>(
                                value: 3, child: Text("删除")),
                            const PopupMenuItem<int>(
                                value: 4, child: Text("保存到相册")),
                          ];
                        },
                        tooltip: '更多',
                        icon: const Icon(Icons.more_horiz_outlined),
                        onSelected: (value) async {
                          if (value == 1) {
                            Share.shareXFiles(<XFile>[XFile(widget.file)]);
                          } else if (value == 2) {
                            OpenFilex.open(widget.file);
                          } else if (value == 3) {
                            setState(() {
                              disabled = true;
                              widget.deleted = true;
                            });
                          } else if (value == 4) {
                            bool status;
                            if (widget.file.endsWith('mp4')) {
                              status = await mediaStore.saveFile(
                                tempFilePath: widget.file,
                                dirType: DirType.video,
                                dirName: DirName.dcim,
                              );
                            } else {
                              status = await mediaStore.saveFile(
                                tempFilePath: widget.file,
                                dirType: DirType.photo,
                                dirName: DirName.dcim,
                              );
                            }
                            widget.showInSnackBar(status ? '保存成功' : '保存失败');
                          }
                        },
                      ),
              ],
            ),
          ),
          Container(
              child: disabled
                  ? null
                  : widget.file.endsWith('mp4')
                      ? VideoWidget(File(widget.file))
                      : Container(
                          margin: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(color: Colors.black, blurRadius: 10),
                            ],
                          ),
                          child: Image(
                            image: FileImage(File(widget.file)),
                          ),
                        ))
        ],
      ),
    );
  }
}

class VideoWidget extends StatefulWidget {
  late final File vidFile;

  VideoWidget(File file, {super.key}) {
    vidFile = file;
  }

  @override
  VideoWidgetState createState() => VideoWidgetState();
}

class VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.vidFile);

    _controller.addListener(() {
      setState(() {});
    });
    _controller.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      VideoPlayer(_controller),
                      _ControlsOverlay(controller: _controller),
                    ],
                  ),
                ),
                SizedBox(
                  height: 15,
                  child: VideoProgressIndicator(_controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                          playedColor: Colors.blue.shade300,
                          bufferedColor: Colors.transparent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({Key? key, required this.controller})
      : super(key: key);

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
      ],
    );
  }
}
