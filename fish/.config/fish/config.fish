if status is-interactive
    # Commands to run in interactive sessions can go here
    starship init fish | source
end

fish_add_path /home/end/.spicetify

# pnpm
set -gx PNPM_HOME "/home/end/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

status --is-interactive; and . (fnm env --use-on-cd | psub)

# opencode
fish_add_path /home/end/.opencode/bin

status --is-interactive; and rbenv init - fish | source
~/.local/bin/mise activate fish | source

alias packettracer="QT_QPA_PLATFORM=xcb /usr/lib/packettracer/packettracer.AppImage"
