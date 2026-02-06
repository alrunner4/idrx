{
  description = "Make it easier to use Idris with Nix";

  inputs = {
    nixpkgs = { type = "indirect"; id = "nixpkgs"; };
  };

  outputs = { self, nixpkgs }:
    let
      decorate-package = { pkgs, buildInputs, runtimeInputs, ipkgName, idrxLibraries, version }:
        let
        system = pkgs.stdenv.hostPlatform.system;
        transitive-dependencies = p: upstream:
          let deps = if builtins.hasAttr "idrxLibraries" p then p.idrxLibraries else [];
          in nixpkgs.lib.unique (deps ++ builtins.concatMap (p: transitive-dependencies p upstream) deps);
        LD_LIBRARY_PATH = object:
          if builtins.hasAttr "LD_LIBRARY_PATH" object
          && builtins.isList object.LD_LIBRARY_PATH
          && builtins.all builtins.isPath object.LD_LIBRARY_PATH
            then object.LD_LIBRARY_PATH
            else let expect-lib-dir = pkgs.runCommand "expect-lib-dir" {} ''
              set -e
              test -d "${object}/lib"
              ln -s "${object}/lib" $out
              '';
            in [ "${expect-lib-dir}" ];
        decorated = p: p // rec {
          idris2 = pkgs.idris2.withPackages (transitive-dependencies (p // {inherit idrxLibraries;}));
          repl = pkgs.writeShellScriptBin "${ipkgName}-repl" ''
            export CPPFLAGS="${
              builtins.concatStringsSep " "
                (builtins.map (i: "-I${i}/include") (buildInputs system pkgs))}"
            LIBPATH="${
              builtins.concatStringsSep ":"
                (builtins.concatMap LD_LIBRARY_PATH (runtimeInputs system pkgs))}"
            export LIBRARY_PATH+=:$LIBPATH
            export LD_LIBRARY_PATH+=:$LIBPATH
            exec ${pkgs.rlwrap}/bin/rlwrap --ansi-colour-aware --no-children \
                ${idris2}/bin/idris2 --repl "${ipkgName}.ipkg"
            '';
          inherit buildInputs runtimeInputs idrxLibraries version;
        };
        in decorated;
    in
    {
      systems = builtins.attrNames nixpkgs.outputs.legacyPackages;
      importFromGitHub = {owner, repo, rev, hash ? ""}: {
        packages = builtins.mapAttrs
          (system: pkgs: (import (pkgs.fetchFromGitHub { inherit owner repo rev hash; }){ idrx = self; }))
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
          (system: pkgs: decorate-package
            { inherit pkgs buildInputs runtimeInputs ipkgName idrxLibraries version; }
            (pkgs.idris2Packages.buildIdris {
              inherit src ipkgName version;
              idrisLibraries = builtins.map (i: i.packages.${system}.library {}) idrxLibraries;
              nativeBuildInputs = buildInputs system pkgs;
              buildInputs = runtimeInputs system pkgs;
            } // {
            })
          )
          nixpkgs.outputs.legacyPackages;
      };
    };
}
