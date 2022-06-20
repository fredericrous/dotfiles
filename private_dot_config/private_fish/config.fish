starship init fish | source

###################################
# Interactive mode configurations #
###################################
status is-interactive || exit

set -x GPG_TTY (tty)
fish_vi_key_bindings
fzf_configure_bindings --directory=\cf --git_log=\cg --git_status=\cs

source $HOME/.iterm2_shell_integration.(basename $SHELL)

set fish_greeting ""
