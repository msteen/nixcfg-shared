{ pkgs, ... }:

{
  environment.variables = {
    JDK_HOME = "${pkgs.jdk}";
    JAVA_HOME = "${pkgs.jdk}";
  };

  environment.systemPackages = with pkgs; [ jdk ];
}
