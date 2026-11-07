{ pkgs, ... }:

let
  # The nixpkgs host bakes in a plain `pass`; give it the pass-otp extension so
  # PASSFF_FIELD_OTP fields can be filled. Not used on macOS, where the hand-installed host
  # in ~/Library/Application Support/Mozilla/NativeMessagingHosts runs Homebrew's pass.
  passWithOtp = pkgs.pass.withExtensions (exts: [ exts.pass-otp ]);
  host = pkgs.passff-host.override { pass = passWithOtp; };
in
{
  home.file.".mozilla/native-messaging-hosts/passff.json".source =
    "${host}/share/passff-host/passff.json";
}
