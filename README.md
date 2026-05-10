# Dotfiles

Dotfiles for `end@frametimee`.

Primary desktop stack:

- `niri`
- `quickshell`
- `fish`
- `wezterm`
- `zed`
- `vicinae`

The expected checkout path is:

```bash
/home/end/projects/dotfiles
```

## Quick Apply

From the repo root:

```bash
stow apps
stow fish
```

`plasma` is intentionally not part of the normal quick apply. Some Plasma files
are machine-local or identity-bearing, so review that package manually before
stowing it.

Reload the active desktop pieces:

```bash
niri msg action load-config-file
quickshell kill -p ~/.config/quickshell 2>/dev/null || true
nohup ~/.local/bin/quickshell-session >/tmp/quickshell.log 2>&1 & disown
systemctl --user daemon-reload
systemctl --user enable --now rfkill-guard.service
```

## Packages Needed

This repo assumes these commands exist on the machine:

```text
brightnessctl
hyprlock
niri
notify-send
playerctl
quickshell
rfkill
stow
upower
wezterm
zed
```

Useful optional tools:

```text
btop
jq
mullvad
nft
tailscale
vicinae
waydroid
```

## Niri

Niri config lives at:

```text
apps/.config/niri/config.kdl
```

Apply changes:

```bash
niri msg action load-config-file
```

Current startup behavior:

- starts Quickshell through `~/.local/bin/quickshell-session`
- starts Vicinae server
- starts Signal, Discord Canary, Zen, qpwgraph, WezTerm, Helium, Obsidian, and Thunderbird
- routes startup apps to the intended workspaces
- maximizes startup app windows

Manual lock is still available:

```text
Super+Alt+L
```

Auto-lock / auto-suspend is currently disabled in `config.kdl`.
The previous `swayidle` autostart was locking the session repeatedly while the
session was active, so it is left commented out until a safer idle setup is
chosen.

## Quickshell

Config lives at:

```text
apps/.config/quickshell
```

Start detached from a terminal:

```bash
nohup ~/.local/bin/quickshell-session >/tmp/quickshell.log 2>&1 & disown
```

Restart:

```bash
quickshell kill -p ~/.config/quickshell 2>/dev/null || true
nohup ~/.local/bin/quickshell-session >/tmp/quickshell.log 2>&1 & disown
```

The launcher script sets:

```bash
QT_QPA_PLATFORMTHEME=kde
QT_STYLE_OVERRIDE=Breeze
```

That keeps native tray menus dark under Niri.

Notification behavior:

- left-click bell: open history
- right-click bell: toggle DND
- DND keeps notifications in history but suppresses toast popups
- notification mode persists in `~/.local/state/quickshell/notification-mode`

Brightness behavior:

- hardware brightness is handled by `brightnessctl`
- below hardware minimum, `display-brightness` uses the Quickshell dim overlay
- state is stored in `~/.local/state/display/dim`

Media keys:

- play/pause, next, and previous use `playerctl`

## RFKill Guard

Purpose: recover Wi-Fi when the Framework/Vicinae radio key path soft-blocks
WLAN.

Files:

```text
apps/.local/bin/rfkill-guard
apps/.local/bin/rfkill-airplane
apps/.config/systemd/user/rfkill-guard.service
```

Enable:

```bash
systemctl --user daemon-reload
systemctl --user enable --now rfkill-guard.service
```

The Niri bindings for `XF86WLAN` and `XF86RFKill` call:

```bash
/home/end/.local/bin/rfkill-airplane
```

This no longer toggles Wi-Fi off. It resumes the guard and unblocks WLAN.

For reliable non-interactive recovery, install this narrow sudoers rule:

```bash
printf 'end ALL=(root) NOPASSWD: /usr/bin/rfkill unblock wlan\n' | sudo tee /etc/sudoers.d/rfkill-unblock-wlan
sudo chmod 0440 /etc/sudoers.d/rfkill-unblock-wlan
sudo visudo -cf /etc/sudoers.d/rfkill-unblock-wlan
```

Check status:

```bash
systemctl --user status rfkill-guard.service --no-pager
journalctl --user -b --no-pager -u rfkill-guard.service
~/.local/bin/rfkill-guard status
```

Manual recovery:

```bash
sudo rfkill unblock wlan
```

## Mullvad + Tailscale

Purpose: keep Tailscale reachable while Mullvad's nftables firewall is active.

Files:

```text
apps/.local/bin/mullvad-tailscale-fix
apps/.config/systemd/system/mullvad-tailscale-fix.service
apps/.config/systemd/system/mullvad-tailscale-fix.timer
mullvad_tailscale.conf
```

Install the root service:

```bash
sudo install -Dm755 /home/end/projects/dotfiles/apps/.local/bin/mullvad-tailscale-fix /home/end/.local/bin/mullvad-tailscale-fix
sudo install -Dm644 /home/end/projects/dotfiles/apps/.config/systemd/system/mullvad-tailscale-fix.service /etc/systemd/system/mullvad-tailscale-fix.service
sudo install -Dm644 /home/end/projects/dotfiles/apps/.config/systemd/system/mullvad-tailscale-fix.timer /etc/systemd/system/mullvad-tailscale-fix.timer
sudo systemctl daemon-reload
sudo systemctl enable --now mullvad-tailscale-fix.timer
sudo systemctl start mullvad-tailscale-fix.service
```

Check:

```bash
systemctl status mullvad-tailscale-fix.timer --no-pager
systemctl status mullvad-tailscale-fix.service --no-pager
ip route show table main | rg '100\.64\.0\.0/10'
sudo nft list chain inet mullvad output | rg 'dotfiles-ts-(daddr|oif)'
```

Do not run `./mullvad_tailscale.conf` as a shell script. It is nft syntax.
If you need to apply it manually:

```bash
sudo nft -f mullvad_tailscale.conf
```

## Waydroid App Labels

Waydroid desktop entries can be relabeled so launcher results are obvious:

```bash
~/.local/bin/waydroid-label-desktop-entries
```

Example result:

```text
[Android] Discord
[Android] Gmail
```

Restart Vicinae after changing desktop entries:

```bash
pkill -f 'vicinae.*server' || true
vicinae server >/tmp/vicinae.log 2>&1 &
```

## Zed Defaults

`apps/.config/mimeapps.list` uses:

```text
dev.zed.Zed-Dev.desktop
```

for code/text defaults. The non-dev `dev.zed.Zed.desktop` entry is not present
on this machine.

## Suspend / Hibernate

The intended system policy is:

- lid close: suspend then hibernate
- delayed hibernate after suspend
- critical battery action: hibernate

Reference configs:

```text
/etc/systemd/logind.conf.d/90-lid-s2h.conf
/etc/systemd/sleep.conf.d/90-s2h.conf
/etc/UPower/UPower.conf
```

Suggested values:

```ini
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
HandleLidSwitchDocked=ignore
```

```ini
[Sleep]
AllowSuspendThenHibernate=yes
HibernateDelaySec=3h
HibernateOnACPower=no
SuspendEstimationSec=10min
```

```ini
UsePercentageForPolicy=true
PercentageLow=20.0
PercentageCritical=5.0
PercentageAction=5.0
CriticalPowerAction=Hibernate
```

Apply system changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart upower.service
```

Verify:

```bash
upower -d | rg -i 'critical-action|percentage'
systemd-analyze cat-config systemd/logind.conf | rg HandleLidSwitch
systemd-analyze cat-config systemd/sleep.conf | rg -E 'AllowSuspendThenHibernate|HibernateDelaySec|HibernateOnACPower|SuspendEstimationSec'
```

## Plasma Package

`plasma` is intentionally conservative.

Tracked theme-style files are okay to keep in the repo. Machine-local state is
ignored or removed from tracking:

```text
plasma/.config/kdeconnect/*
plasma/.config/kwinoutputconfig.json
plasma/.config/QtProject.conf
```

Do not blindly stow Plasma without reviewing the diff first.

## Troubleshooting

Check stow conflicts:

```bash
stow -nv apps
stow -nv fish
stow -nv plasma
```

Check Quickshell logs:

```bash
quickshell log -p ~/.config/quickshell
tail -f /tmp/quickshell.log
```

Check Niri state:

```bash
niri msg -j windows
niri msg -j layers
```

Check battery state:

```bash
upower -i /org/freedesktop/UPower/devices/battery_BAT1
cat /sys/class/power_supply/BAT1/status
cat /sys/class/power_supply/BAT1/capacity
```
