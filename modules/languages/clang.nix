{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with builtins; let
  cfg = config.vim.languages.clang;

  defaultServer = "ccls";
  servers = {
    ccls = {
      package = pkgs.ccls;
      lspConfig = ''
        lspconfig.ccls.setup{
          capabilities = capabilities;
          on_attach=default_on_attach;
          cmd = {"${cfg.lsp.package}/bin/ccls"};
          ${optionalString (cfg.lsp.opts != null) "init_options = ${cfg.lsp.opts}"}
        }
      '';
    };
    clangd = {
      package = pkgs.clang-tools;
      lspConfig = ''
        local clangd_cap = capabilities
        -- use same offsetEncoding as null-ls
        clangd_cap.offsetEncoding = {"utf-16"}
        lspconfig.clangd.setup{
          capabilities = clangd_cap;
          on_attach=default_on_attach;
          cmd = {"${cfg.lsp.package}/bin/clangd"};
          ${optionalString (cfg.lsp.opts != null) "init_options = ${cfg.lsp.opts}"}
        }
      '';
    };
  };
in {
  options.vim.languages.clang = {
    enable = mkEnableOption "C/C++ language support";

    cHeader = mkOption {
      description = ''
        C syntax for headers. Can fix treesitter errors, see:
        https://www.reddit.com/r/neovim/comments/orfpcd/question_does_the_c_parser_from_nvimtreesitter/
      '';
      type = types.bool;
      default = false;
    };

    treesitter = {
      enable = mkEnableOption "C/C++ treesitter" // {default = config.vim.languages.enableTreesitter;};
      cPackage = nvim.types.mkGrammarOption pkgs "c";
      cppPackage = nvim.types.mkGrammarOption pkgs "cpp";
    };

    lsp = {
      enable = mkEnableOption "Enable clang LSP support" // {default = config.vim.languages.enableLSP;};

      server = mkOption {
        description = "The clang LSP server to use";
        type = with types; enum (attrNames servers);
        default = defaultServer;
      };

      package = mkOption {
        description = "clang LSP server package";
        type = types.package;
        default = servers.${cfg.lsp.server}.package;
      };

      opts = mkOption {
        description = "Options to pass to clang LSP server";
        type = with types; nullOr str;
        default = null;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.cHeader {
      vim.configRC.c-header = nvim.dag.entryAnywhere "let g:c_syntax_for_h = 1";
    })

    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [cfg.treesitter.cPackage cfg.treesitter.cppPackage];
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.lspconfig.enable = true;

      vim.lsp.lspconfig.sources.clang-lsp = servers.${cfg.lsp.server}.lspConfig;
    })
  ]);
}
