import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'main.dart';

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
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
    return Scaffold(
      appBar: AppBar(
        title: const Text('库'),
      ),
      body: const VideoList(),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
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

getFileSize(FileSystemEntity file, int decimals) {
  try {
    int bytes = File(file.path).lengthSync();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "K", "M", "G", "T", "P", "E", "Z", "Y"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  } catch (e) {
    return 0;
  }
}

class _VideoListState extends State<VideoList> {
  _VideoListState();

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  final List<Widget> kids = <Widget>[];
  final List<bool> kidsRemoved = <bool>[];

  @override
  Widget build(BuildContext context) {
    const storagePath = 'DCIM/LogCam';
    const dcimPath = '/storage/emulated/0/$storagePath';
    final dir = Directory(dcimPath);
    if (dir.existsSync()) {
      int idx = 0;
      for (final file in Directory(dcimPath).listSync().reversed) {
        if (!file.path.endsWith('mp4') && !file.path.endsWith('jpg')) {
          continue;
        }
        kidsRemoved.add(false);
        kids.add(AbsorbPointer(
          absorbing: kidsRemoved[idx],
          child: VideoCard(idx, file, showInSnackBar),
        ));
        idx++;
      }
    }
    return ListView(
      children: kids,
    );
  }
}

class VideoCard extends StatefulWidget {
  late final int idx;
  late final FileSystemEntity file;
  late final Function showInSnackBar;
  VideoCard(int i, FileSystemEntity f, Function ssb, {super.key}) {
    idx = i;
    file = f;
    showInSnackBar = ssb;
  }

  @override
  State<StatefulWidget> createState() => VideoCardState();
}

class VideoCardState extends State<VideoCard> {
  bool disabled = false;

  @override
  void dispose() {
    if (disabled) {
      try {
        if (widget.file.existsSync()) {
          widget.file.deleteSync();
        }
      } catch (e) {
        widget.showInSnackBar('删除的过程中发生了错误..错误信息已经复制到剪切板，请把它发给我!');
        widget.showInSnackBar('你也可以手动到DCIM/LogCam中删除文件');
        Clipboard.setData(ClipboardData(text: e.toString()));
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: disabled ? Colors.grey : Colors.white,
      child: Column(
        children: <Widget>[
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
                widget.file.path.endsWith('mp4') ? Icons.movie : Icons.image),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.file.path.split('/').last.split('.').first}'
                    ' (${getFileSize(widget.file, 1)})'),
                disabled
                    ? IconButton(
                        tooltip: '撤销',
                        onPressed: () {
                          setState(() {
                            disabled = false;
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
                          ];
                        },
                        tooltip: '更多',
                        icon: const Icon(Icons.more_horiz_outlined),
                        onSelected: (value) {
                          if (value == 3) {
                            setState(() {
                              disabled = true;
                            });
                          } else if (value == 1) {
                            Share.shareXFiles(<XFile>[XFile(widget.file.path)]);
                          } else if (value == 2) {
                            OpenFilex.open(widget.file.path);
                          }
                        },
                      ),
              ],
            ),
          ),
          Container(
              child: disabled
                  ? null
                  : widget.file.path.endsWith('mp4')
                      ? VideoWidget(File(widget.file.path))
                      : Image(
                          image: FileImage(File(widget.file.path)),
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
