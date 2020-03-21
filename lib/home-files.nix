args: name: [
  (import ./files.nix args {
    path = [ "home" name ];
    root = "/home/${name}";
    fileMode = "664";
    dirMode = "775";
    user = name;
    group = name;
  })
]
