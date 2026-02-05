{
  description = "Make it easier to use Idris with Nix";

  inputs = {
    nixpkgs = { type = "indirect"; id = "nixpkgs"; };
  };

  outputs = { self, nixpkgs }:
    let
      decorate-package = pkgs:
        let
        transitive-dependencies = p: upstream:
          let deps = p.idrisLibraries upstream ++ p.idrxLibraries;
          in nixpkgs.lib.unique (deps ++ builtins.concatMap (transitive-dependencies upstream) deps);
        LD_LIBRARY_PATH = object:
          if builtins.hasAttr "LD_LIBRARY_PATH" object
            && builtins.isList object.LD_LIBRARY_PATH
            && builtins.all builtins.isPath object.LD_LIBRARY_PATH
            then object.LD_LIBRARY_PATH
            else let expect-lib-dir = pkgs.runCommand {
              name = "expect-lib-dir";
              buildCommand = ''
                set -e
                test -d "${object}/lib"
                ln -s "${object}/lib" $out
                '';
              }; in [ "${expect-lib-dir}" ];
        in p: p // rec {
          idris2 = pkgs.idris2.withPackages (transitive-dependencies p);
          repl = pkgs.writeShellScriptBin "${p.ipkgName}-repl" ''
            export CPPFLAGS="${
              builtins.concatStringsSep " "
                (builtins.map (i: "-I${i}/include") p.buildInputs)}"
            LIBPATH="${
              builtins.concatStringsSep ":"
                (builtins.map LD_LIBRARY_PATH p.runtimeInputs)}"
            export LIBRARY_PATH+=:$LIBPATH
            export LD_LIBRARY_PATH+=:$LIBPATH
            exec ${pkgs.rlwrap}/bin/rlwrap --ansi-colour-aware --no-children \
                ${idris2}/bin/idris2 --repl "${p.ipkgName}.ipkg"
            '';
        };
    in
    {
      systems = builtins.attrNames nixpkgs.outputs.legacyPackages;
      importFromGitHub = {owner, repo, rev, hash ? ""}: {
        packages = builtins.mapAttrs
          (system: pkgs: decorate-package pkgs
            (import (pkgs.fetchFromGitHub { inherit owner repo rev hash; }){ idrx = self; }))
          nixpkgs.outputs.legacyPackages;
      };
      importFromSrc = {
        src,
        ipkgName,
        version ? "",
        idrxLibraries ? [],
        buildInputs ? _: _: [],
        runtimeInputs ? _: _: []}
      :{
        packages = builtins.mapAttrs
          (system: pkgs: decorate-package pkgs
            (pkgs.idris2Packages.buildIdris {
              inherit src ipkgName version;
              idrisLibraries = builtins.map (i: i.packages.${system}.library {}) idrxLibraries;
              nativeBuildInputs = buildInputs system pkgs;
              buildInputs = runtimeInputs system pkgs;
            } // {
              inherit buildInputs runtimeInputs ipkgName idrisLibraries idrxLibraries version;
            })
          )
          nixpkgs.outputs.legacyPackages;
      };
    };
}
