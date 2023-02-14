// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logcam/ffmpeg.dart';
import 'package:logcam/videoview.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:wakelock/wakelock.dart';

const String dcimPath = '/storage/emulated/0/DCIM/LogCam';

/// Camera example home widget.
class CameraExampleHome extends StatefulWidget {
  /// Default Constructor
  const CameraExampleHome({Key? key}) : super(key: key);

  @override
  State<CameraExampleHome> createState() {
    return _CameraExampleHomeState();
  }
}

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int? selectCam;
  CameraController? controller;
  XFile? imageFile;
  XFile? videoFile;
  VideoPlayerController? videoController;
  VoidCallback? videoPlayerListener;
  bool enableAudio = true;
  bool isProcessing = false;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;

  // Counting pointers (number of user fingers on screen)
  int _pointers = 0;

  int orientation = 0;
  static const oris = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([oris[orientation]]);

    if (_cameras.isNotEmpty) {
      onSwitchCameraButtonPressed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // #docregion AppLifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }
  // #enddocregion AppLifecycle

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                    color:
                        controller != null && controller!.value.isRecordingVideo
                            ? Colors.redAccent
                            : isProcessing
                                ? Colors.green
                                : Colors.grey,
                    width: 3.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
            ),
          ),
          _captureControlRowWidget(),
        ],
      ),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (isProcessing ||
        cameraController == null ||
        !cameraController.value.isInitialized) {
      return Text(
        '等待${isProcessing ? '视频处理' : '摄像头'}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        child: Center(
          child: CameraPreview(
            controller!,
            child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onTapDown: (TapDownDetails details) =>
                    onViewFinderTap(details, constraints),
              );
            }),
          ),
        ),
      );
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await controller!.setZoomLevel(_currentScale);
  }

  bool hasNewContent = false;
  Widget _captureControlRowWidget() {
    final CameraController? cameraController = controller;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
            tooltip: '库',
            icon: Icon(hasNewContent ? Icons.new_releases : Icons.video_file),
            color: hasNewContent ? Colors.orange : Colors.blue.shade900,
            onPressed: (() async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: ((context) => const VideoViewPage())));
              setState(() {
                hasNewContent = false;
              });
              SystemChrome.setPreferredOrientations([oris[orientation]]);
            })),
        const SizedBox(
          height: 1,
          width: 25,
          child: Divider(
            thickness: 0.5,
            color: Colors.black,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.cameraswitch),
          color: Colors.cyan,
          tooltip: '切换摄像头',
          onPressed: _cameras.isNotEmpty ? onSwitchCameraButtonPressed : null,
        ),
        IconButton(
          icon: const Icon(Icons.camera_alt),
          color: Colors.blue,
          tooltip: '拍照',
          onPressed: cameraController != null &&
                  cameraController.value.isInitialized &&
                  !cameraController.value.isRecordingVideo
              ? onTakePictureButtonPressed
              : null,
        ),
        IconButton(
          tooltip: '录像',
          icon: Icon(cameraController != null &&
                  cameraController.value.isRecordingVideo
              ? Icons.stop
              : Icons.videocam),
          color: cameraController != null &&
                  cameraController.value.isRecordingVideo
              ? Colors.red
              : Colors.blue,
          onPressed:
              cameraController != null && cameraController.value.isInitialized
                  ? !cameraController.value.isRecordingVideo
                      ? onVideoRecordButtonPressed
                      : onStopButtonPressed
                  : null,
        ),
        IconButton(
          icon: const Icon(Icons.screen_rotation),
          color: Colors.black,
          tooltip: '旋转',
          onPressed: onRotateScreenButtonPressed,
        ),
      ],
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
  double timestampInt() => DateTime.now().millisecondsSinceEpoch / 1000;

  void showInSnackBar(String message, {int duration = 4000}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: Duration(milliseconds: duration),
    ));
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    final CameraController? oldController = controller;
    if (oldController != null) {
      controller = null;
      await oldController.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        showInSnackBar('摄像机错误 ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      await Future.wait(<Future<Object?>>[
        // The exposure mode is currently not supported on the web.
        ...!kIsWeb ? <Future<Object?>>[] : <Future<Object?>>[],
        cameraController
            .getMaxZoomLevel()
            .then((double value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((double value) => _minAvailableZoom = value),
      ]);
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          showInSnackBar('没有摄像头权限捏');
          break;
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('请到设置中手动开启摄像头权限');
          break;
        case 'CameraAccessRestricted':
          // iOS only
          showInSnackBar('Camera access is restricted.');
          break;
        case 'AudioAccessDenied':
          showInSnackBar('没有录音权限捏');
          break;
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          showInSnackBar('Please go to Settings app to enable audio access.');
          break;
        case 'AudioAccessRestricted':
          // iOS only
          showInSnackBar('Audio access is restricted.');
          break;
        default:
          _showCameraException(e);
          break;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  String getTimeStr(DateTime now) {
    return '${now.year % 100}-${now.month}-${now.day}_${now.hour};${now.minute};${now.second}';
  }

  void onTakePictureButtonPressed() {
    takePicture().then((XFile? file) {
      if (mounted) {
        setState(() {
          videoController?.dispose();
          videoController = null;
        });
        final DateTime now = DateTime.now().toLocal();
        startTimeStr = getTimeStr(now);
        final processPath = '$dcimPath/$startTimeStr.jpg';
        if (file != null) {
          processPic(file.path, processPath,
              _cameras[selectCam!].lensDirection == CameraLensDirection.front,
              (session) async {
            if (ReturnCode.isSuccess(await session.getReturnCode())) {
              setState(() {
                hasNewContent = true;
              });
            } else {
              final String ret = (await session.getOutput()).toString();
              Clipboard.setData(ClipboardData(text: ret));
              showInSnackBar('操作的过程中发生了错误..错误信息已经复制到剪切板，请把它发给我!');
            }
            File(file.path).delete();
          });
        }
      }
    });
  }

  void onSwitchCameraButtonPressed() async {
    if (selectCam != null) {
      if (_cameras.length > 1) {
        selectCam = (selectCam! + 1) % _cameras.length;
        onNewCameraSelected(_cameras[selectCam!]);
      }
    } else {
      if (_cameras.isNotEmpty) {
        selectCam = 0;
        onNewCameraSelected(_cameras[0]);
      }
    }
  }

  late double startTime;
  late String startTimeStr;

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((_) {
      if (mounted) {
        setState(() {});
      }
      startTime = timestampInt();
      final DateTime now = DateTime.now().toLocal();
      startTimeStr = getTimeStr(now);
    });
  }

  void onStopButtonPressed() {
    final that = this;
    stopVideoRecording().then((XFile? file) {
      if (mounted) {
        setState(() {});
      }
      if (file != null) {
        final String processPath = '$dcimPath/$startTimeStr.mp4';

        that.setState(() {
          isProcessing = true;
        });

        final isFrontCam =
            _cameras[selectCam!].lensDirection == CameraLensDirection.front;

        processVid(file.path, processPath, startTime, isFrontCam,
            (session) async {
          that.setState(() {
            isProcessing = false;
          });
          if (ReturnCode.isSuccess(await session.getReturnCode())) {
            File(file.path).delete();
            setState(() {
              hasNewContent = true;
            });
          } else {
            Clipboard.setData(ClipboardData(text: await session.getOutput()));
            showInSnackBar('视频的处理过程中发生了错误..错误信息已经复制到剪切板，请把它发给我!');
          }
        });
      }
    });
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.startVideoRecording();
      Wakelock.enable();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      return null;
    }

    try {
      final XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  Future<XFile?> stopVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      Wakelock.disable();
      return cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.pauseVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> resumeVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.resumeVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setExposureMode(ExposureMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setExposureMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  void _showCameraException(CameraException e) {
    showInSnackBar('错误: ${e.code}\n${e.description}');
  }

  void onRotateScreenButtonPressed() {
    orientation = (orientation + 1) % oris.length;
    SystemChrome.setPreferredOrientations([oris[orientation]]);
  }
}

/// CameraApp is the Main Application.
class CameraApp extends StatelessWidget {
  /// Default Constructor
  const CameraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CameraExampleHome(),
    );
  }
}

List<CameraDescription> _cameras = <CameraDescription>[];

final mediaStorePlugin = MediaStore();

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  WidgetsFlutterBinding.ensureInitialized();

  List<Permission> permissions = [
    Permission.storage,
    Permission.camera,
    Permission.microphone,
    Permission.manageExternalStorage,
  ];

  if ((await mediaStorePlugin.getPlatformSDKInt()) >= 33) {
    permissions.add(Permission.photos);
    permissions.add(Permission.audio);
    permissions.add(Permission.videos);
  }

  await permissions.request();

  try {
    _cameras = await availableCameras();
  } on CameraException catch (_) {}

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CameraApp());
}
