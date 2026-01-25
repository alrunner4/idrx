{
  description = "Make it easier to use Idris with Nix";

  inputs = {
    nixpkgs = { type = "indirect"; id = "nixpkgs"; };
  };

  outputs = { self, nixpkgs }:
    let
        transitive-dependencies = p: nixpkgs.lib.unique
          (p.idrisLibraries ++ builtins.concatMap transitive-dependencies p.idrisLibraries);
        decorate-package = pkgs: p: p // rec {
          idrisLibrariesClosure = transitive-dependencies p;
          repl = pkgs.writeShellScriptBin "${p.ipkgName}-repl" ''
            export IDRIS2_PACKAGE_PATH+=:${
              builtins.concatStringsSep ":"
                (builtins.map
                  (dep: "${dep.library {}}/lib/idris2-${pkgs.idris2.version}")
                  idrisLibrariesClosure)}
            exec ${pkgs.rlwrap}/bin/rlwrap --ansi-colour-aware --no-children \
                ${pkgs.idris2}/bin/idris2 --repl ${p.ipkgName}.ipkg
            '' // { buildInputs = p.buildInputs; };
        };
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        lib = {
          inherit pkgs;
          importFromGitHub = {owner, repo, rev, hash ? ""}:
            let pkg = import (pkgs.fetchFromGitHub { inherit owner repo rev hash; })
              { idrx = self; };
            in decorate-package pkgs pkg;
          importFromSrc = {src, ipkgName, idrisLibraries ? [], version ? "", buildInputs ? [], runtimeInputs ? []}:
            decorate-package pkgs
              (pkgs.idris2Packages.buildIdris {inherit src ipkgName idrisLibraries version; nativeBuildInputs = buildInputs; buildInputs = runtimeInputs; }
                // { inherit buildInputs runtimeInputs ipkgName idrisLibraries version; });
          upstream = pkgs.idris2Packages;
        };
    in
    {
      packages.x86_64-linux = {
        default = pkgs.hello;
        inherit lib;
      };
    } // lib;
}
