{ pkgs, ... }:

{
  packages = [
    pkgs.nodejs_24
  ];

  git-hooks.hooks = {
    deadnix = {
      enable = true;
      settings.edit = true;
    };
    nixfmt-rfc-style.enable = true;
    nil.enable = true;
  };

}
