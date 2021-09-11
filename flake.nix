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
    nix-bundler = {
      url = "github:matthewbauer/nix-bundle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-utils = {
      url = "github:tomberek/nix-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, neovim, nix-bundler, nix-utils}:
    let pkgs = import nixpkgs {system = "x86_64-linux";};
        DSL = rec {
          # TODO add in case for attrset with args2LuaTable?
          primitive2Lua = (prim: if builtins.isBool prim then (if prim then "true" else "false") else (if builtins.isInt prim then "${builtins.toString prim}" else "\"${prim}\""));
          # name: what to call
          # args: [String]
          callFn = (name: args:
            "${name}(${builtins.foldl' (acc: ele: acc ++ ", " ++ ele) args})");

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
              primitive2Lua args));
          expr2Lua = (path: args:
            if builtins.isAttrs args then
              let attrNames = builtins.attrNames args;
              in (builtins.foldl' (acc: ele:
                let root = if "${path}" == "" then "" else "${path}.";
                    val = (expr2Lua "${root}${ele}" args.${ele});
                in "${acc}\n${val}") "" attrNames)
            else
              "${path} = ${primitive2Lua args}");

          accessAttr = (root: attr: (if "${root}" != "" then "${root}.${attr}" else "${attr}"));
          accessAttrList = (seq: builtins.foldl' accessAttr "" seq);

          # vim specific
          genOpt = (scope: name: value:
            let attr = (accessAttrList [ "vim" "${scope}" "${name}" ]);
            in "${attr} = ${args2LuaTable value}");
          genGlobalOpt = genOpt "o";
          setGlobalOpt = s: genOpt s true;

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

            config = {
              vim.o = {
                showcmd = true;
                showmatch = true;
                ignorecase = true;
                smartcase = true;
                cursorline = true;
                wrap = true;
                autoindent = true;
                copyindent = true;
                splitbelow = true;
                splitright = true;
                number = true;
                relativenumber = true;
                title = true;
                noerrorbells = true;
                undofile = true;
                autoread = true;
                hidden = true;
                nofoldenable = true;
                list = true;
                backspace = "indent,eol,start";
                undolevels = 1000000;
                undoreload = 1000000;
                foldmethod = "indent";
                foldnestmax = 10;
                foldlevel = 1;
                scrolloff = 3;
                sidescrolloff = 5;
                listchars = "tab:→→,trail:●,nbsp:○";
                clipboard = "unnamed,unnamedplus";
              };
            };

          tempConfig = builtins.foldl' (acc: ele: "${acc}\n${ele}") ""
            [
              (setGlobalOpt "showcmd")
              (setGlobalOpt "showmatch")
              (setGlobalOpt "ignorecase")
              (setGlobalOpt "smartcase")
              (setGlobalOpt "cursorline")
              (setGlobalOpt "wrap")
              (setGlobalOpt "autoindent")
              (setGlobalOpt "copyindent")
              (setGlobalOpt "splitbelow")
              (setGlobalOpt "splitright")
              (setGlobalOpt "autoindent")
              (setGlobalOpt "copyindent")
              (setGlobalOpt "splitbelow")
              (setGlobalOpt "splitright")
              (setGlobalOpt "number")
              (setGlobalOpt "relativenumber")
              (setGlobalOpt "title")
              (setGlobalOpt "noerrorbells")
              (setGlobalOpt "undofile")
              (setGlobalOpt "autoread")
              (setGlobalOpt "hidden")
              (setGlobalOpt "nofoldenable")
              (setGlobalOpt "list")

              (genGlobalOpt "backspace" "indent,eol,start")
              (genGlobalOpt "undolevels" "1000000")
              (genGlobalOpt "undoreload" "1000000")
              (genGlobalOpt "foldmethod" "indent")
              (genGlobalOpt "foldnestmax" 10)
              (genGlobalOpt "foldlevel" 1)
              (genGlobalOpt "scrolloff" 3)
              (genGlobalOpt "sidescrolloff" 5)
              (genGlobalOpt "listchars" "tab:→→,trail:●,nbsp:○")
              (genGlobalOpt "clipboard" "unnamed,unnamedplus")
            ];

        };


        # TODO you should generalize this...
        wrapNvim = (configText:
          let configFile = pkgs.writeText "luaConfigFile" configText; in
          neovim.defaultPackage.x86_64-linux.overrideAttrs (prev: {
            nativeBuildInputs = prev.nativeBuildInputs ++ [pkgs.makeWrapper];
            postFixup = ''
              mkdir -p $out/nvim/
              cp ${configFile} $out/nvim/init.lua
              mv $out/bin/nvim $out/bin/nvim_unwrapped
              makeWrapper $out/bin/nvim_unwrapped $out/bin/nvim --add-flags -u\ $out/nvim/init.lua
            '';
          })
        );
        result_nvim = pkgs.wrapNeovim (wrapNvim DSL.tempConfig) {
          withNodeJs = true;
          #plugins = with pkgs.vimPlugins; [
            #nerdcommenter
          #];
        };
  in
  {
  	nvim = neovim.defaultPackage.x86_64-linux;

    defaultPackage.x86_64-linux = result_nvim;
    nix-bundle = nix-bundler.defaultBundler { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    rpm = nix-utils.bundlers.rpm { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    deb = nix-utils.bundlers.deb { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    DSL = DSL;

    config = pkgs.writeText "config" (DSL.expr2Lua "" DSL.config);

  };
}