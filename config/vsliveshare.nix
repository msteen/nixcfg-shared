{
  imports = [
    "${builtins.fetchGit {
      url = "https://github.com/msteen/nixos-vsliveshare.git";
      ref = "refs/heads/master";
    }}"
  ];

  services.vsliveshare.enable = true;
}
