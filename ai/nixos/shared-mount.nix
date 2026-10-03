# Type of a host directory a container shares read-write with the stack.
lib:
lib.types.submodule {
  options = {
    hostPath = lib.mkOption { type = lib.types.str; };
    mountPoint = lib.mkOption { type = lib.types.str; };
  };
}
