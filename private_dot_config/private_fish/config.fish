if test (uname -s) = "Darwin"
  set -gx PATH /usr/local/opt/coreutils/libexec/gnubin $PATH
  set -gx PATH /usr/local/opt/gnu-sed/libexec/gnubin $PATH
  set -gx PATH /Applications/p4merge.app/Contents/MacOS $PATH
  set -gx PATH /Users/fredericrous/Library/AndroidSDK/bin $PATH
  set -gx PATH "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" $PATH

  set -g fish_user_paths "/usr/local/opt/openjdk/bin" $fish_user_paths
  set -g fish_user_paths "/usr/local/opt/mysql-client/bin" $fish_user_paths

  set -gx ANDROID_HOME /Users/fredericrous/Library/AndroidSDK
  set -gx JAVA_HOME /usr/local/opt/openjdk
end

set -gx PATH ~/.config/git/bin $PATH
set -gx EDITOR /usr/bin/vim
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x LESS "--ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --tabs=4 --window=-4"
set -gx RIPGREP_CONFIG_PATH "$HOME/.ripgreprc"

if test "$COLORTERM" = "truecolors"
  set -gx LS_COLORS (vivid generate lava)
else
  set -gx LS_COLORS (vivid -m 8-bit generate lava)
end

set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

###################################
# Interactive mode configurations #
###################################
status is-interactive || exit

starship init fish | source
set -gx GPG_TTY (tty)
source ~/.iterm2_shell_integration.(basename $SHELL)
fish_vi_key_bindings
fzf_configure_bindings --directory=\cf --git_log=\cl --git_status=\cs
set fish_greeting ""

