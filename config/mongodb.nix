{ pkgs, ... }:

{
  boot = {
    kernelParams = [ "transparent_hugepage=never" ];
    
    postBootCommands = ''
      # https://docs.mongodb.com/v3.2/tutorial/transparent-huge-pages/
      echo never > /sys/kernel/mm/transparent_hugepage/enabled
      echo never > /sys/kernel/mm/transparent_hugepage/defrag
    '';
  };

  environment.systemPackages = with pkgs; [ mongodb-tools ];

  services.mongodb.enable = true;
}
