{
  fullName,
  mail,
  ...
}:

{
  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings.user.name = "${fullName}";
    settings.user.email = "${mail}";
  };
}
