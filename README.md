# logcam

a vlog cam, written in flutter

resolution is forced to 240p (320x240)
audio bitrate is forced to 8 kbps with `acc` encoding (as reference, a high-quality WAV file has an audio bitrate at 1,411 kbps)


any media saved will be processed by ffmpeg first.

ffmpeg command for image:

```
FFmpegKit.execute("-i ${file.path}"
        " -movflags use_metadata_tags"
        " -vf \"drawtext=fontfile=/system/fonts/DroidSansMono.ttf"
        ": text='%{localtime\\:%x %X}': fontcolor=white@0.5"
        ": x=h/50: y=(h-text_h)-h/50: fontsize=h/25"
        ": shadowcolor=black: shadowx=1: shadowy=1\""
```

as well as for video:

```
FFmpegKit.execute("-i ${file.path}"
        " -vcodec libx264 -crf 30"
        " -movflags use_metadata_tags"
        " -vf \"drawtext=fontfile=/system/fonts/DroidSansMono.ttf"
        ": text='%{pts\\:localtime\\:$startTime\\:%x %X}': fontcolor=white@0.5"
        ": x=h/50: y=(h-text_h)-h/50: fontsize=h/25"
        ": shadowcolor=black: shadowx=1: shadowy=1\""
        " -c:a aac -b:a 8k"
```

development are under NixOS, type `nix-shell shell.nix` to initialize the shell painlessly.
