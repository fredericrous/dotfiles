
if not set -q XDG_CONFIG_HOME
  set -x XDG_CONFIG_HOME $HOME/.config
end
if not set -q XDG_DATA_HOME
  set -x XDG_DATA_HOME $HOME/.local/share
end

if test (uname -s) = "Darwin"
  set -gx ANDROID_HOME /Users/fredericrous/Library/AndroidSDK
  set -gx JAVA_HOME /usr/local/opt/openjdk
  set -gx PATH /usr/local/opt/coreutils/libexec/gnubin $PATH
  set -gx PATH /usr/local/opt/gnu-sed/libexec/gnubin $PATH
  set -gx PATH /Applications/p4merge.app/Contents/MacOS $PATH
  set -gx PATH "$ANDROID_HOME/bin" $PATH
  set -gx PATH "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" $PATH

  set -g fish_user_paths "/usr/local/opt/openjdk/bin" $fish_user_paths
  set -g fish_user_paths "/usr/local/opt/mysql-client/bin" $fish_user_paths

  set -x HOMEBREW_BUNDLE_FILE $XDG_CONFIG_HOME/Brewfile
end

set -gx PATH $XDG_CONFIG_HOME/git/bin $PATH

set -gx EDITOR /usr/bin/vim
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x LESS "--ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --tabs=4 --window=-4"

set FZF_DEFAULT_OPTS_BASE \
   --ansi --no-bold \
   --marker='*' \
   --cycle \
   --layout=reverse --preview-window=wrap \
   --bind "'ctrl-\:toggle-preview'" \
   --bind "'ctrl-x:execute-silent(echo {+} | clipboard-provider copy)'"
set -x FZF_TMUX_DEFAULT_OPTS '-p 75%'
set -x FZF_DEFAULT_COMMAND 'fd --type=file --type=directory --hidden --color=always .'

set fzf_preview_dir_cmd $FZF_DEFAULT_COMMAND
set fzf_history_opts --preview ''
set fzf_dir_opts --bind 'ctrl-o:execute(command nvim {} >/dev/tty)'

set -x WGETRC $XDG_CONFIG_HOME/wgetrc
set -x RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgreprc"
set -x GNUPGHOME "$XDG_CONFIG_HOME/gnupg"
set -x CURL_HOME "$XDG_CONFIG_HOME/curl"

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
fzf_configure_bindings --directory=\cf --git_log=\cg --git_status=\cs

set fish_greeting ""

__fish_apple_touchbar_bind_key 1 '👈' 'prevd' '-s'
__fish_apple_touchbar_bind_key 2 '🗄 jump' 'cdh' '-s'
__fish_apple_touchbar_bind_key 3 '📒 list' 'ls -l' '-s'
__fish_apple_touchbar_bind_key 4 '𖡻 du' 'dust' '-s'
__fish_apple_touchbar_bind_key 5 '🚦 top' 'sudo htop' '-s'
__fish_apple_touchbar_bind_key 6 '📊 btm' 'btm' '-s'
__fish_apple_touchbar_bind_key 7 '╂ split' 'osascript -e "tell application \"System Events\" to key code 2 using command down"'
__fish_apple_touchbar_bind_key 8 '┿ split' 'osascript -e "tell application \"System Events\" to key code 2 using {shift down, command down}"'
__fish_apple_touchbar_bind_key 9 '📂 open' 'open .' '-s'
__fish_apple_touchbar_bind_key 10 '👨‍💻 code lines' 'tokei' '-s'
