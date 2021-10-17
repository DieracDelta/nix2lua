{
  description = "A very basic flake";

  inputs = {
    nixpkgs = { url = "github:NixOS/nixpkgs/master"; };
    home-manager = {
      url = "github:nix-community/home-manager/release-21.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim = {
      url = "github:neovim/neovim?rev=88336851ee1e9c3982195592ae2fc145ecfd3369&dir=contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-bundler = {
      url = "github:matthewbauer/nix-bundle";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    telescope-src = {
      url = "github:nvim-telescope/telescope.nvim?rev=b5c63c6329cff8dd8e23047eecd1f581379f1587";
      flake = false;
    };
    nix-utils = {
      url = "github:tomberek/nix-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dracula-nvim = {
      url = "github:Mofiqul/dracula.nvim";
      flake = false;
    };
    nvim-cmp = {
      url = "github:hrsh7th/nvim-cmp";
      flake = false;
    };
    nvim-cmp-lsp = {
      url = "github:hrsh7th/cmp-nvim-lsp";
      flake = false;
    };
    cmp-buffer = {
      url = "github:hrsh7th/cmp-buffer";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, neovim, nix-bundler, nix-utils, dracula-nvim, ...}:
    let pkgs = import nixpkgs {system = "x86_64-linux";};
        DSL = rec {
          # TODO add in case for attrset with args2LuaTable?
          primitive2Lua = (prim: if builtins.isBool prim then (if prim then "true" else "false") else (if builtins.isInt prim || builtins.isFloat prim then "${builtins.toString prim}" else "'${prim}'"));
          # name: what to call
          # args: [primitive]
          callFn = (name: args:
            "${name}(${builtins.foldl' (acc: ele: acc + (if acc == "" then "" else ",") + (args2LuaTable ele) ) "" args})");

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
            let fnCall = callFn "require" [ "${name}" ];
            in bindLocal name fnCall);
          # TODO check arguments form
          genKeybind = ({mode ? "", combo ? "", command ? "", opts ? {} }:
            callFn (accessAttrList [ "vim" "api" "nvim_set_keymap" ]) [
              "${mode}"
              "${combo}"
              "${command}"
              opts
            ]);

          config = {
            extraConfig = "

local cmp = require('cmp')
 cmp.setup({
    mapping = {
      ['<C-n>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
      ['<C-p>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
      ['<Down>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
      ['<Up>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
      ['<C-d>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.close(),
      ['<CR>'] = cmp.mapping.confirm({
        behavior = cmp.ConfirmBehavior.Replace,
        select = true,
      })
    },
    sources = {
      { name = 'nvim_lsp' },
      { name = 'buffer' },
    }
  })

local lspc = require('lspconfig')
lspc.rust_analyzer.setup({
  cmd = { '${pkgs.rust-analyzer}/bin/rust-analyzer' },
  capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
})
require('lsp_signature').setup({
  bind = true,
  hint_enable = false,
  hi_parameter = 'Visual',
  handler_opts = {
    border = 'single'
  }
})
require('nvim-treesitter.configs').setup({
 ensure_installed = {'bash', 'c', 'css', 'javascript', 'json', 'lua', 'nix', 'python', 'rust', 'toml'},
 highlight = {
   enable = true,
   disable = {'css'}
 },
 rainbow = {
   enable = true,
   disable = {'html'},
   extended_mode = true,
   max_file_lines = 10000,
   colors = {'#bd93f9', '#6272a4', '#8be9fd', '#50fa7b', '#f1fa8c', '#ffb86c', '#ff5555'}
 }
})
            ";
            setOptions = {
              vim.g = {
                mapleader = " ";
                nofoldenable = true;
                noshowmode = true;
                completeopt = "menu,menuone,noselect";
              };
              vim.o = {
                termguicolors = true;
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
                background = "dark";
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
              #lspconfig = {
                #bash = {
                #};
                #rnix = {
                #};
              #};
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
              {
                mode = "n";
                combo = "<leader>ws";
                command = "<cmd>sp<cr>";
              }
              {
                mode = "n";
                combo = "<leader>wv";
                command = "<cmd>vs<cr>";
              }
              {
                mode = "n";
                combo = "<leader>bd";
                command = "<cmd>q<cr>";
              }
              {
                mode = "n";
                combo = "<leader>bn";
                command = "<cmd>tabnext<cr>";
              }
              {
                mode = "n";
                combo = "<leader>bp";
                command = "<cmd>tabprevious<cr>";
              }
              {
                mode = "n";
                combo = "<leader>bN";
                command = "<cmd>tabedit<cr>";
              }
              {
                mode = "n";
                combo = "<leader>bD";
                command = "<cmd>Bclose!<cr>";
              }
              {
                mode = "n";
                combo = "<leader>wd";
                command = "<cmd>q<cr>";
              }
              {
                mode = "n";
                combo = "<leader>wl";
                command = "<cmd>wincmd l<cr>";
              }
              {
                mode = "n";
                combo = "<leader>wj";
                command = "<cmd>wincmd j<cr>";
              }
              {
                mode = "n";
                combo = "<leader>wk";
                command = "<cmd>wincmd k<cr>";
              }
              {
                mode = "n";
                combo = "<leader>wh";
                command = "<cmd>wincmd h<cr>";
              }
              {
                mode = "n";
                combo = "<space>D";
                command = "<cmd>lua\tvim.lsp.buf.declaration()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>d";
                command = "<cmd>lua\tvim.lsp.buf.definition()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "K";
                command = "<cmd>lua\tvim.lsp.buf.hover()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>i";
                command = "<cmd>lua\tvim.lsp.buf.implementation()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<C-k>";
                command = "<cmd>lua\tvim.lsp.buf.signature_help()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>k";
                command = "<cmd>lua\tvim.lsp.buf.type_definition()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>rn";
                command = "<cmd>lua\tvim.lsp.buf.rename()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>ca";
                command = "<cmd>lua\tvim.lsp.buf.code_action()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>r";
                command = "<cmd>lua\tvim.lsp.buf.references()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>e";
                command = "<cmd>lua\tvim.lsp.diagnostic.show_line_diagnostics()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
              {
                mode = "n";
                combo = "<space>f";
                command = "<cmd>lua\tvim.lsp.buf.formatting()<CR>";
                opts = {"noremap" = true; "silent" = true;};
              }
            ];
            rawLua = [
              (callFn "vim.cmd" ["syntax on"])
              (callFn "vim.cmd" ["colorscheme dracula"])
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
              (builtins.foldl' (acc: ele: acc + "\n" + ele) "" config.rawLua) +
              "${config.extraConfig}" +
              "\nEOF";
        };



        result_nvim = pkgs.wrapNeovim (neovim.defaultPackage.x86_64-linux) {
          withNodeJs = true;
          configure.customRC = DSL.neovimBuilder DSL.config;
          configure.packages.myVimPackage.start = with pkgs.vimPlugins; [
            (pkgs.vimUtils.buildVimPluginFrom2Nix { pname = "dracula-nvim"; version = "master"; src = dracula-nvim; })
            (telescope-nvim.overrideAttrs (oldattrs: { src = inputs.telescope-src; }))
            (cmp-buffer.overrideAttrs (oldattrs: { src = inputs.cmp-buffer; }))
            (nvim-cmp.overrideAttrs (oldattrs: { src = inputs.nvim-cmp; }))
            (cmp-nvim-lsp.overrideAttrs (oldattrs: { src = inputs.nvim-cmp-lsp; }))
            plenary-nvim
            nerdcommenter
            nvim-lspconfig
            lspkind-nvim
            (pkgs.vimPlugins.nvim-treesitter.withPlugins (
              plugins: with plugins; [tree-sitter-nix tree-sitter-python tree-sitter-c tree-sitter-rust]
            ))
            lsp_signature-nvim
            popup-nvim
          ];
        };
  in
  {
    nvim = neovim.defaultPackage.x86_64-linux;

    defaultPackage.x86_64-linux = result_nvim;
    # TODO nix portable
    nix-bundle = nix-bundler.defaultBundler { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    rpm = nix-utils.bundlers.rpm { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    deb = nix-utils.bundlers.deb { program = "${result_nvim}/bin/nvim"; system = "x86_64-linux";};
    DSL = DSL;

    config = pkgs.writeText "config" (DSL.neovimBuilder DSL.config);

  };
}
