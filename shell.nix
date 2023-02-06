{ pkgs ? import <nixpkgs> {} }:
let android-nixpkgs = (pkgs.callPackage (import (builtins.fetchGit {url = "https://github.com/tadfisher/android-nixpkgs.git";})) {channel = "stable";});

in pkgs.mkShell {
  buildInputs = with pkgs; [
    flutter
    #android build
    (android-nixpkgs.sdk (sdkPkgs: with sdkPkgs; [
      cmdline-tools-latest
      build-tools-30-0-3
      build-tools-33-0-0
      platform-tools
      platforms-android-31
      platforms-android-33
      tools
      patcher-v4
      system-images-android-31-default-x86-64
      emulator]))
    jdk unzip
    ungoogled-chromium
  ];
  #declaring FLUTTER_ROOT
  FLUTTER_ROOT = pkgs.flutter;
  #libepoxy workaround
  LD_LIBRARY_PATH = "${pkgs.libepoxy}/lib";
  #web chrome and dart-sdk workaround
  CHROME_EXECUTABLE = "chromium";
  shellHook = ''
    if ! [ -d $HOME/.cache/flutter/ ]
    then
    mkdir $HOME/.cache/flutter/
    fi
    ln -f -s ${pkgs.flutter}/bin/cache/dart-sdk $HOME/.cache/flutter/
  '';
}
