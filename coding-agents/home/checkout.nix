# Authored agent files (skills, rules, agents) are linked out of store so they stay writable
# and editable without a rebuild; that needs a checkout of this tree on the machine.
{ config, lib, ... }:
{
  options.home.aiStack.checkout = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos-config/coding-agents";
    description = "Writable checkout of the coding-agents/ tree that out-of-store links point into.";
  };
}
