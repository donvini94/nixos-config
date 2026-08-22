# PokeMMO ships a self-updating tree: a small Java launcher (pokemmo_updater.jar)
# populates ~/.local/share/pokemmo and then executes bin/linux/x64/PokeMMO — a
# GraalVM native-image client built for generic glibc systems (interpreter
# /lib64/ld-linux-x86-64.so.2, ~30 further libraries resolved by dlopen).
# The launcher overwrites that tree on every game update, so patchelf'ing it
# would not survive a single patch day; the launcher runs inside an FHS sandbox
# instead and the client inherits it.
#
# nixpkgs' pokemmo-installer (1.4.8) is not usable: its script still runs
# `com.pokeemu.updater.ClientUpdater` and `java -cp PokeMMO.exe
# com.pokeemu.client.Client`. Upstream moved the launcher entry point to
# com.pokemmo.launcher.Launcher and PokeMMO.exe is now a Windows PE binary, so
# both code paths abort on a current install.
{
  lib,
  buildFHSEnv,
  writeShellScript,
  writeText,
}:

let
  # Published by the PokeMMO developers to authenticate the launcher. The jar is
  # the only artifact we fetch ourselves; everything it writes afterwards is
  # verified against PokeMMO's own signed feeds.
  signingKey = writeText "pokemmo-updater-key.pem" ''
    -----BEGIN PUBLIC KEY-----
    MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAyfYQx1kSfIVGdGzcHmVV
    P7cbyLsMXGdLhwMnx2AD1MYgU170iFN5gHT+U248rH10L6D1UMlZK1LfCsbPkdQO
    ir3C+8Do212NONyNm/7+ZGeIwbpy+jxEQH8Jfn4JYY7+Sn4qg249yW7DSY+XKvTO
    cphoXRNzSQp8u6IVj03mIw7zDA0SqMMFtnCXVP3NRmtjK1SuVVFLltFctz1Pp7f9
    uqgqnFlgD2l8/THnddTRM5IR6O9pbOXu7My0+Jli6+4zJgw5gQvgivYPCeess9gW
    Rqpw66VTpMJERJYA6AIbVierAbjGmtRETRsHUOGAgo54G0oxtXXEaTWXF6n6mdgS
    E2Ra8q7P23stsSWU3mDNQjXO0XOhtAKQCZfvICxmsH3ed5hm8bEC5yga8z8m0vyZ
    71fWzP4Q3g6B+o6oDsMX1nWbV2GEHci/6nwFofgOJkLINaZfUTivAIRuxECVwjTT
    a7ruRNgFlA2ciGUIIke2Ev2cYzyBA4LLARky2FZiEM0VAgMBAAE=
    -----END PUBLIC KEY-----
  '';

  launcher = writeShellScript "pokemmo-launcher" ''
    set -euo pipefail

    data=''${XDG_DATA_HOME:-$HOME/.local/share}/pokemmo
    jar=$data/pokemmo_updater.jar

    mkdir -p "$data"

    # The launcher keeps itself current once installed, so this only runs on a
    # fresh machine. A mirror that serves an unsigned jar is skipped rather than
    # trusted: this jar is what fetches and executes the rest of the game.
    if [ ! -f "$jar" ]; then
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT

      for mirror in \
        https://dl.pokemmo.eu \
        https://files.pokemmo.eu \
        https://dl.pokemmo.download \
        https://dl.pokemmo.com
      do
        echo "pokemmo: fetching launcher from $mirror" >&2
        wget --https-only --quiet --tries=3 --timeout=10 --directory-prefix="$work" \
          "$mirror/download/updater/pokemmo_updater.jar" \
          "$mirror/download/updater/pokemmo_updater.sig256" || continue

        if openssl dgst -sha256 -verify ${signingKey} \
          -signature "$work/pokemmo_updater.sig256" "$work/pokemmo_updater.jar" >/dev/null
        then
          install -Dm644 "$work/pokemmo_updater.jar" "$jar"
          break
        fi

        echo "pokemmo: $mirror served a launcher that fails signature verification" >&2
        rm -f "$work"/pokemmo_updater.*
      done

      if [ ! -f "$jar" ]; then
        echo "pokemmo: no mirror served a verifiable launcher" >&2
        exit 1
      fi
    fi

    cd "$data"
    exec java -jar "$jar" "$@"
  '';
in
buildFHSEnv {
  name = "pokemmo";

  runScript = launcher;

  targetPkgs =
    pkgs: with pkgs; [
      # Launcher itself: JRE for the jar, wget/openssl for the bootstrap above.
      jre
      openssl
      wget

      # Windowing. SDL3 drives the client; GLFW is still linked in and both
      # backends are probed, so the X11 and Wayland library sets must be there
      # whichever compositor the client ends up selecting.
      libdecor
      libxkbcommon
      wayland
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcursor
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXinerama
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libXxf86vm

      # Graphics. libglvnd dispatches to the driver under /run/opengl-driver,
      # which the FHS env puts on the loader path for us.
      libGL
      libdrm
      libgbm
      sdl3
      vulkan-loader

      # Native file dialogs (LWJGL nfd) and the tray icon. Missing GTK is what
      # makes the client die in NativeFileDialog.<clinit> during startup; the
      # FHS env links only what is listed, so GTK's own dependencies come too.
      atk
      cairo
      gdk-pixbuf
      glib
      gtk3
      harfbuzz
      libayatana-appindicator
      libepoxy
      pango
      xdg-utils
      zenity

      # Audio. The client probes several backends and dlopens whichever answers.
      alsa-lib
      jack2
      libpulseaudio
      openal
      portaudio

      # Remaining dlopen targets of the native image.
      dbus
      fribidi
      jemalloc
      libarchive
      libthai
      stdenv.cc.cc.lib
      systemdLibs
      zlib
    ];

  meta = {
    description = "MMO built on the Pokémon Gen 3/4 engines, sandboxed for its self-updating client";
    homepage = "https://pokemmo.com";
    license = lib.licenses.unfree;
    mainProgram = "pokemmo";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
