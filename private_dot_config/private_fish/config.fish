starship init fish | source
zoxide init fish | source

###################################
# Interactive mode configurations #
###################################
status is-interactive || exit

set -x GPG_TTY (tty)
fish_vi_key_bindings
fzf_configure_bindings --directory=\cf --git_log=\cg --git_status=\cs

source $HOME/.iterm2_shell_integration.(basename $SHELL)

set fish_greeting ""

eval "$(conda "shell.$(basename "$SHELL")" hook)"

# pnpm
set -gx PNPM_HOME "/Users/fredericrous/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

set --export RUST_BACKTRACE full

direnv hook fish | source

# Added by Windsurf
fish_add_path /Users/fredericrous/.codeium/windsurf/bin

# Added by Antigravity
fish_add_path /Users/fredericrous/.antigravity/antigravity/bin
