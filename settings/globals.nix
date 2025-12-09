{
  # Global configuration variables available throughout your flake

  # User configuration
  user = {
    name = "dustin";
    fullName = "Dustin Krysak";
    email = "dustin@bashfulrobot.com";
    homeDirectory = "/home/dustin";
  };

  # System defaults
  defaults = {
    stateVersion = "25.11";
    timeZone = "America/Vancouver";
    locale = "en_US.UTF-8";
  };

  # Editor and shell preferences
  preferences = {
    editor = "helix";  # Package name in nixpkgs
    shell = "fish";
  };
}
