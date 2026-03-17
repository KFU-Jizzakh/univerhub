Rails.application.config.typst_bin_path =
  ENV.fetch("TYPST_BIN_PATH", nil) ||
  `which typst 2>/dev/null`.chomp.presence ||
  File.expand_path("~/.local/bin/typst")
