{ config, pkgs, lib, ... }:
let
  cfg = config.nvimConfig;

  # English LanguageTool n-gram data, used by ltex-ls-plus for context-aware
  # real-word error detection (their/there, its/it's). The archive unpacks to
  # the n-gram index directories directly; we name that tree `en` because ltex
  # expects a `<languageModel>/<lang>/` layout. Version + hash are pinned from
  # the maintained github:Janik-Haag/nix-languagetool-ngram project.
  ltexNgramsEn = pkgs.fetchzip {
    url = "https://languagetool.org/download/ngram-data/ngrams-en-20150817.zip";
    hash = "sha256-v3Ym6CBJftQCY5FuY6s5ziFvHKAyYD3fTHr99i6N8sE=";
  };
in {
  options.nvimConfig.ltexNgrams.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Download the English LanguageTool n-gram data (~8 GB) and place it where
      ltex-ls-plus auto-detects it (~/.local/share/ltex/ngrams/en), enabling
      context-aware spelling of real-word errors. Set to false to skip the
      large download; ltex still runs, just without n-gram rules.
    '';
  };

  config = {
    # Tools required by this nvim config (language servers, formatters, etc.).
    # Added to the user's home-manager packages so a `nixos-rebuild switch`
    # ensures everything nvim expects is on PATH.
    home.packages = import ./packages.nix pkgs;

    # Place the n-gram data at the path lua/plugins/lsp.lua probes. home-manager
    # symlinks the store path in, so it costs a symlink on top of the download.
    home.file.".local/share/ltex/ngrams/en" = lib.mkIf cfg.ltexNgrams.enable {
      source = ltexNgramsEn;
    };
  };
}
