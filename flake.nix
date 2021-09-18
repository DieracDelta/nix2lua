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
    vitality-plugins = {
      url = "github:DieracDelta/vim-plugins-overlay";
    };
  };

  outputs = { self, nixpkgs, home-manager, neovim, nix-bundler, nix-utils, vitality-plugins}:
    let pkgs = import nixpkgs {overlays = [vitality-plugins.outputs.overlay]; system = "x86_64-linux";};
        DSL = rec {
          # TODO add in case for attrset with args2LuaTable?
          primitive2Lua = (prim: if builtins.isBool prim then (if prim then "true" else "false") else (if builtins.isInt prim || builtins.isFloat prim then "${builtins.toString prim}" else "'${prim}'"));
          # name: what to call
          # args: [String]
          callFn = (name: args:
            "${name}(${builtins.foldl' (acc: ele: acc + (if acc == "" then "" else ",") + ele ) "" args})");

          args2LuaTable = (args:
            (if builtins.isList args then
              (builtins.foldl' (acc: ele: acc + (if acc == "{" then "" else ",") + "${args2LuaTable ele}") "{" args)
              + "}"
            else if builtins.isAttrs args then
            (if pkgs.lib.hasAttrByPath ["isObject"] args then
               # TODO assert has other attr
               "${args.content}"
             else
               (let attrNames = builtins.attrNames args;
               in (builtins.foldl' (acc: ele:
                 let val = (args2LuaTable args.${ele});
                 in "${acc}${if acc == "{" then '''' else '',''} ${ele} = ${val}") "{" attrNames) + "}")
            )
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
          luaExpr = expr: {
            isObject = true;
            content = expr;
          };

          bindLocal = (name: expr: "local ${name} = ${expr}");
          reqPackage = (name:
            let fnCall = callFn "require" [ "'${name}'" ];
            in bindLocal name fnCall);
          # TODO check arguments form
          genKeybind = ({mode ? "", combo ? "", command ? "", opts ? {} }:
            callFn (accessAttrList [ "vim" "api" "nvim_set_keymap" ]) [
              "'${mode}'"
              "'${combo}'"
              "'${command}'"
              "${args2LuaTable opts}"
            ]);

          config = {
            setOptions = {
              vim.g = {
                mapleader = " ";
                nofoldenable = true;
                noshowmode = true;
              };
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
                undofile = true;
                autoread = true;
                hidden = true;
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
                formatoptions = "tcqj";
                encoding = "utf-8";
                fileencoding = "utf-8";
                fileencodings = "utf-8";
                bomb = true;
                binary = true;
                matchpairs = "(:),{:},[:],<:>";
                expandtab = true;
                pastetoggle = "<leader>v";
                wildmode = "list:longest,list:full";
              };
            };
            pluginInit = {
              telescope = {
                defaults = {
                  file_ignore_patterns = [
                    "flake.lock"
                    "yarn.lock"
                  ];
                  layout_config = {
                    width = 0.99;
                    height = 0.99;
                  };
                  mappings = {
                    i = {
                      "['<c-j>']" = luaExpr "require('telescope.actions').move_selection_next";
                      "['<c-k>']" = luaExpr "require('telescope.actions').move_selection_previous";
                    };
                    n = {
                      "['<c-j>']" = luaExpr "require('telescope.actions').move_selection_next";
                      "['<c-k>']" = luaExpr "require('telescope.actions').move_selection_previous";
                    };
                  };
                };
              };
            };
            keybinds = [
              {
                mode = "n";
                combo = "j";
                command = "gj";
                opts = {"noremap" = true; };
              }
              {
                mode = "n";
                combo = "k";
                command = "gk";
                opts = {"noremap" = true; };
              }
              {
                mode = "n";
                combo = "<leader>bb";
                command = "<cmd>Telescope buffers<cr>";
              }
              {
                mode = "n";
                combo = "<leader>gg";
                command = "<cmd>Telescope live_grep<cr>";
              }
              {
                mode = "n";
                combo = "<leader><leader>";
                command = "<cmd>Telescope find_files<cr>";
              }
            ];
          };
		  genPlugin = attrName: attrSet: ''require('${attrName}').setup(${args2LuaTable attrSet})'';
          neovimBuilder =
            config:
              # HACK find a way to pass this in with an init.lua
              "lua << EOF\n" +
              (expr2Lua "" config.setOptions) + "\n" +
              (builtins.foldl' (acc: ele: acc + "\n" + ele) "" (map genKeybind config.keybinds)) +
              (builtins.foldl' (acc: ele: acc + "\n" + ele) "" (pkgs.lib.mapAttrsToList genPlugin config.pluginInit)) +
              "\nEOF";
        };



        result_nvim = pkgs.wrapNeovim (neovim.defaultPackage.x86_64-linux) {
          withNodeJs = true;
          configure.customRC = DSL.neovimBuilder DSL.config;
          configure.packages.myVimPackage.start = with pkgs.vimPlugins; with pkgs.vitalityVimPlugins; [
            telescope-nvim
            plenary-nvim
            nerdcommenter
          ];
        };
  in
  {
    nvim = neovim.defaultPackage.x86_64-linux;

    defaultPackage.x86_64-linux = result_nvim;
    nix-bundle = nix-bundler.defaultBundler { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    rpm = nix-utils.bundlers.rpm { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    deb = nix-utils.bundlers.deb { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    DSL = DSL;

    config = pkgs.writeText "config" (DSL.neovimBuilder DSL.config);

  };
}
