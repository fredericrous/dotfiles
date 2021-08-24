
###################################
# Interactive mode configurations #
###################################
status is-interactive || exit

starship init fish | source
set -x GPG_TTY (tty)
source $HOME/.iterm2_shell_integration.(basename $SHELL)
fish_vi_key_bindings
fzf_configure_bindings --directory=\cf --git_log=\cg --git_status=\cs

set fish_greeting ""
