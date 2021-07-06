status is-interactive || exit

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
