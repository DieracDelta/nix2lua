{
  description = "A very basic flake";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/release-21.05"; };
    home-manager = {
      url = "github:nix-community/home-manager/release-21.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim = {
      url = "github:neovim/neovim?rev=88336851ee1e9c3982195592ae2fc145ecfd3369&dir=contrib";
      #rev =  "release-0.5";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, neovim}:
    let pkgs = import nixpkgs {system = "x86_64-linux";};
        DSL = rec {
          # name: what to call
          # args: [String]
          callFn = (name: args:
            "${name}(${builtins.foldl' (acc: ele: acc ++ ", " ++ ele) args})");

          # builtins.hasAttr "blah" attrset
          # TODO this needs to be looked into

          args2LuaTable = (args:
            (if builtins.isList args then
              (builtins.foldl' (acc: ele: acc + "${args2LuaTable ele}, ") "{" args)
              + "}"
            else if builtins.isAttrs args then
              let attrNames = builtins.attrNames args;
              in (builtins.foldl' (acc: ele:
                let val = (args2LuaTable args.${ele});
                in "${acc} ${ele} = ${val},") "{" attrNames) + "}"
            else
              builtins.toString args));
          accessAttr = (root: attr: "${root}.${attr}");
          accessAttrList = (seq: builtins.foldl' accessAttr seq);

          # vim specific
          genOpt = (name: value:
            let attr = (accessAttrList [ "vim" "opt" "${name}" ]);
            in "${attr} = ${value}");
          bindLocal = (name: expr: "local ${name} = ${expr}");
          reqPackage = (name:
            let fnCall = callFn "require" [ "'${name}'" ];
            in bindLocal name fnCall);
          # TODO check arguments form
          genKeybind = (mode: combo: command: opts:
            callFn (accessAttrList [ "vim" "api" "nvim_set_keymap" ]) [
              "'${mode}'"
              "'${combo}'"
              "'${command}'"
              "${args2LuaTable opts}"
            ]);
        };
        tempConfig = ''
          local o = vim.o
          local wo = vim.wo
          local bo = vim.bo

          -- global options
          o.swapfile = true
          o.dir = '/tmp'
          o.smartcase = true
          o.laststatus = 2
          o.hlsearch = true
          o.incsearch = true
          o.ignorecase = true
          o.scrolloff = 12
        '';

        wrapNvim = (configText:
          let configFile = pkgs.writeText "luaConfigFile" configText; in
          neovim.defaultPackage.x86_64-linux.overrideAttrs (prev: {
            nativeBuildInputs = prev.nativeBuildInputs ++ [pkgs.makeWrapper];
            postFixup = ''
              mkdir -p $out/nvim/
              cp ${configFile} $out/nvim/init.lua
              makeWrapper $out/bin/nvim $out/bin/nvim-nix --set XDG_CONFIG_HOME $out/nvim/init.lua
            '';
          })
        );
  in
  {
    #neovim = neovim.defaultPackage.x86_64-linux;

    defaultPackage.x86_64-linux = wrapNvim tempConfig;

  };
}
