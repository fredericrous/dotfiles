status is-interactive || exit

__fish_apple_touchbar_bind_key 1 '๐' 'prevd' '-s'
__fish_apple_touchbar_bind_key 2 '๐ jump' 'cdh' '-s'
__fish_apple_touchbar_bind_key 3 '๐ list' 'ls -l' '-s'
__fish_apple_touchbar_bind_key 4 '๐กป du' 'dust' '-s'
__fish_apple_touchbar_bind_key 5 '๐ฆ top' 'sudo htop' '-s'
__fish_apple_touchbar_bind_key 6 '๐ btm' 'btm' '-s'
__fish_apple_touchbar_bind_key 7 'โ split' 'osascript -e "tell application \"System Events\" to key code 2 using command down"'
__fish_apple_touchbar_bind_key 8 'โฟ split' 'osascript -e "tell application \"System Events\" to key code 2 using {shift down, command down}"'
__fish_apple_touchbar_bind_key 9 '๐ open' 'open .' '-s'
__fish_apple_touchbar_bind_key 10 '๐จโ๐ป code lines' 'tokei' '-s'
