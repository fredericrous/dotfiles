
# tmpdir
if not set -q TMPDIR
  set -x TMPDIR /tmp
end

# xdg directories
if not set -q XDG_CONFIG_HOME
  set -x XDG_CONFIG_HOME $HOME/.config
end
if not set -q XDG_DATA_HOME
  set -x XDG_DATA_HOME $HOME/.local/share
end
if not set -q XDG_BIN_HOME
  set -x XDG_BIN_HOME $HOME/.local/bin
end
if not set -q XDG_CACHE_HOME
  set -x XDG_CACHE_HOME $HOME/.cache
end
if not set -q XDG_RUNTIME_DIR
  if mkdir -p "$TMPDIR/runtime" &>/dev/null
    set -x XDG_RUNTIME_DIR "$TMPDIR/runtime"
  else
    set -x XDG_RUNTIME_DIR $TMPDIR
  end
end

if test -d /opt/homebrew
    set -l HOMEBREW_HOME /opt/homebrew
else if test -d /home/linuxbrew/.linuxbrew
    set -l HOMEBREW_HOME /home/linuxbrew/.linuxbrew
else
    set -l HOMEBREW_HOME /usr/local
end

set -gx JAVA_HOME $HOMEBREW_HOME/opt/openjdk
set -gx PATH $HOMEBREW_HOME/opt/coreutils/libexec/gnubin $PATH
set -gx PATH $HOMEBREW_HOME/opt/gnu-sed/libexec/gnubin  $PATH
set -gx PATH $HOMEBREW_HOME/bin  $PATH
set -gx PATH $XDG_CONFIG_HOME/git/bin
set -g fish_user_paths "$HOMEBREW_HOME/opt/openjdk/bin" $fish_user_paths
set -g fish_user_paths "$HOMEBREW_HOME/opt/mysql-client/bin" $fish_user_paths

set -x HOMEBREW_BUNDLE_FILE $XDG_CONFIG_HOME/Brewfile

if test (uname -s) = "Darwin"
  set -gx ANDROID_HOME $HOME/Library/AndroidSDK
  set -gx PATH "$ANDROID_HOME/bin" $PATH
  set -gx PATH /Applications/p4merge.app/Contents/MacOS $PATH
  set -gx PATH "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" $PATH
end

set -gx EDITOR /usr/bin/vim
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x LESS "--ignore-case --LONG-PROMPT --RAW-CONTROL-CHARS --tabs=4 --window=-4"

set -x FZF_DEFAULT_OPTS \
   --ansi --no-bold \
   --marker='*' \
   --height 40% \
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
set -x GNUPGHOME "$HOME/.gnupg"
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
set -x GPG_TTY (tty)
source $HOME/.iterm2_shell_integration.(basename $SHELL)
fish_vi_key_bindings
fzf_configure_bindings --directory=\cf --git_log=\cg --git_status=\cs

set fish_greeting ""
