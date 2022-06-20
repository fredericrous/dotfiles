#!/bin/sh
chmod +x "${XDG_CONFIG_HOME:-~/.config}"/git/git-templates/templates/hooks/* || true

# run_once hash: {{ include "private_dot_config/git/git-templates/templates/hooks" | sha256sum }}
