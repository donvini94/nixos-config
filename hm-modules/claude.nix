{ ... }:

{
  # ~/.claude points into Syncthing's ~/Claude folder. Sync memory, not sessions
  # or credentials; instructions are application-owned.
  home.file.".claude/.stignore".text = ''
    !/memory
    *
  '';
}
