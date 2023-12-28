{
disko.devices.disk.nvme0n1 = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          start = "1MiB";
          end = "512MiB";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
	 root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@" = { mountpoint = "/"; };
              "@home" = {
                mountOptions = [ "compress=zstd" ];
                mountpoint = "/home";
              };
              "@nix" = {
                mountOptions = [ "compress=zstd" "noatime" ];
                mountpoint = "/nix";
              };
            };
          };
        };
      };
    };
  };

}
