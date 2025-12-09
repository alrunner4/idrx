{
  description = "Make it easier to use Idris with Nix";

  inputs = {
    nixpkgs = { type = "indirect"; id = "nixpkgs"; };
  };

  outputs = { self, nixpkgs }:
    let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        lib = {
          inherit pkgs;
          importFromGitHub = {owner, repo, rev, hash ? ""}:
              import (pkgs.fetchFromGitHub { inherit owner repo rev hash; })
                  { idrx = self; };
          importFromSrc = pkgs.idris2Packages.buildIdris;
          upstream = pkgs.idris2Packages;
        };
    in
    {
      packages.x86_64-linux = {
        default = pkgs.hello // lib;
        inherit lib;
      };
    } // lib;
}
