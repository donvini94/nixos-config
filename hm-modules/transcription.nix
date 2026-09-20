{
  pkgs,
  ...
}:

let
  client = pkgs.callPackage ../packages/local-transcription-client.nix { };

  # The model translates to English when it guesses the language wrong, so every
  # entry point forces one. "auto" is still accepted and means "let it guess".
  defaultLanguage = "English";

  requireServer = ''
    if ! ${pkgs.systemd}/bin/systemctl is-active --quiet local-transcription.service \
      || ! ${pkgs.curl}/bin/curl --fail --silent --max-time 2 --output /dev/null http://127.0.0.1:8272/health; then
      ${pkgs.libnotify}/bin/notify-send --urgency=critical \
        "Local transcription is unavailable" \
        "Run transcription-start and wait for the model to become ready."
      exit 1
    fi
  '';

  languageFlag = ''
    language="$1"
    set --
    if [ "$language" != "auto" ]; then
      set -- --language "$language"
    fi
  '';

  dictationRunner = pkgs.writeShellApplication {
    name = "transcription-dictation-run";
    runtimeInputs = [
      client
      pkgs.coreutils
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:?}/local-transcription"
      mkdir -p "$runtime_dir"
      rm -f "$runtime_dir/dictation.txt"
      ${languageFlag}
      exec local-transcription-client \
        --source microphone \
        --transcript "$runtime_dir/dictation.txt" \
        "$@"
    '';
  };

  meetingRunner = pkgs.writeShellApplication {
    name = "transcription-meeting-run";
    runtimeInputs = [
      client
      pkgs.coreutils
      pkgs.libnotify
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:?}/local-transcription"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/transcription"
      mkdir -p "$runtime_dir" "$state_dir"

      timestamp=$(date +%Y-%m-%d_%H-%M-%S)
      base="$state_dir/meeting-$timestamp"
      printf '%s\n' "$base" > "$runtime_dir/meeting-current"
      notify-send "Meeting transcription started" "Saving $base.txt and $base.wav"

      ${languageFlag}
      exec local-transcription-client \
        --source meeting \
        --transcript "$base.txt" \
        --audio-output "$base.wav" \
        "$@"
    '';
  };

  dictationToggle = pkgs.writeShellApplication {
    name = "transcription-dictate-toggle";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
      pkgs.systemd
      pkgs.wtype
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:?}/local-transcription"
      mkdir -p "$runtime_dir"
      transcript="$runtime_dir/dictation.txt"
      instance_file="$runtime_dir/dictation-unit"

      if [ -f "$instance_file" ]; then
        unit=$(cat "$instance_file")
        if systemctl --user is-active --quiet "$unit"; then
          systemctl --user stop "$unit"
          rm -f "$instance_file"
          if [ -s "$transcript" ]; then
            # Without the leading sleep the compositor is still applying the
            # virtual keymap and swallows the first character.
            wtype -s 150 -- "$(cat "$transcript")"
            notify-send "Dictation inserted"
          else
            notify-send "No speech recognized"
          fi
          exit 0
        fi
        rm -f "$instance_file"
      fi

      ${requireServer}
      unit="transcription-dictation@''${1:-${defaultLanguage}}.service"
      systemctl --user start "$unit"
      printf '%s\n' "$unit" > "$instance_file"
      notify-send "Dictation started" "Press the same shortcut again to insert the text."
    '';
  };

  meetingStart = pkgs.writeShellApplication {
    name = "transcription-meeting-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
      pkgs.systemd
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:?}/local-transcription"
      mkdir -p "$runtime_dir"
      instance_file="$runtime_dir/meeting-unit"

      if [ -f "$instance_file" ] && systemctl --user is-active --quiet "$(cat "$instance_file")"; then
        echo "Meeting transcription is already running."
        exit 0
      fi

      ${requireServer}
      unit="transcription-meeting@''${1:-${defaultLanguage}}.service"
      systemctl --user start "$unit"
      printf '%s\n' "$unit" > "$instance_file"
    '';
  };

  meetingStop = pkgs.writeShellApplication {
    name = "transcription-meeting-stop";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
      pkgs.systemd
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:?}/local-transcription"
      instance_file="$runtime_dir/meeting-unit"

      if [ ! -f "$instance_file" ] || ! systemctl --user is-active --quiet "$(cat "$instance_file")"; then
        echo "Meeting transcription is not running."
        exit 0
      fi

      systemctl --user stop "$(cat "$instance_file")"
      rm -f "$instance_file"
      if [ -f "$runtime_dir/meeting-current" ]; then
        base=$(cat "$runtime_dir/meeting-current")
        notify-send "Meeting transcription saved" "$base.txt and $base.wav"
        printf 'Transcript: %s.txt\nAudio: %s.wav\n' "$base" "$base"
      fi
    '';
  };

  meetingStatus = pkgs.writeShellApplication {
    name = "transcription-meeting-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      runtime_dir="''${XDG_RUNTIME_DIR:?}/local-transcription"
      instance_file="$runtime_dir/meeting-unit"

      if [ -f "$instance_file" ]; then
        systemctl --user --no-pager status "$(cat "$instance_file")" || true
      else
        echo "Meeting transcription is not running."
      fi
      if [ -f "$runtime_dir/meeting-current" ]; then
        base=$(cat "$runtime_dir/meeting-current")
        printf 'Transcript: %s.txt\nAudio: %s.wav\n' "$base" "$base"
      fi
    '';
  };

  captureService = description: runner: {
    Unit.Description = description;
    Service = {
      Type = "simple";
      ExecStart = "${runner}/bin/${runner.name} %i";
      KillSignal = "SIGTERM";
      KillMode = "mixed";
      TimeoutStopSec = "60s";
    };
  };
in
{
  home.packages = [
    client
    dictationToggle
    meetingStart
    meetingStop
    meetingStatus
  ];

  systemd.user.services = {
    "transcription-dictation@" =
      captureService "Focused-field local voice dictation (%i)" dictationRunner;
    "transcription-meeting@" =
      captureService "Local meeting recording and transcription (%i)" meetingRunner;
  };
}
