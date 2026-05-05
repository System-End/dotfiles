# Dotfiles Notes

## Tailscale + Mullvad coexistence

Do not run `./mullvad_tailscale.conf` directly in a shell.
That file is nft syntax, not bash. Use `sudo nft -f ...` if you need it.
For day-to-day use, prefer the timer/service flow below.

Canonical setup in this repo:

- `apps/.local/bin/mullvad-tailscale-fix`
- `apps/.config/systemd/system/mullvad-tailscale-fix.service`
- `apps/.config/systemd/system/mullvad-tailscale-fix.timer`

One-time setup (requires root):

```bash
sudo install -Dm755 /home/end/projects/dotfiles/apps/.local/bin/mullvad-tailscale-fix /home/end/.local/bin/mullvad-tailscale-fix
sudo install -Dm644 /home/end/projects/dotfiles/apps/.config/systemd/system/mullvad-tailscale-fix.service /etc/systemd/system/mullvad-tailscale-fix.service
sudo install -Dm644 /home/end/projects/dotfiles/apps/.config/systemd/system/mullvad-tailscale-fix.timer /etc/systemd/system/mullvad-tailscale-fix.timer

sudo systemctl daemon-reload
sudo systemctl enable --now mullvad-tailscale-fix.timer
sudo systemctl start mullvad-tailscale-fix.service
```

Optional (dotfiles-style symlink for script updates):

```bash
ln -sfn /home/end/projects/dotfiles/apps/.local/bin/mullvad-tailscale-fix /home/end/.local/bin/mullvad-tailscale-fix
```

Manual run:

```bash
sudo /home/end/.local/bin/mullvad-tailscale-fix
```

Quick health check:

```bash
systemctl status mullvad-tailscale-fix.timer --no-pager
ip route show table main | rg "100\.64\.0\.0/10"
sudo nft list chain inet mullvad output | rg "dotfiles-ts-(daddr|oif)"
```

Rule cleanup note:

- Do not delete nft rules by expression for this case.
- Use handles only:

```bash
sudo nft -a list chain inet mullvad output
# then delete old unmanaged tailscale lines by handle, for example:
# sudo nft delete rule inet mullvad output handle 123
sudo systemctl start mullvad-tailscale-fix.service
```

Common command mistakes (avoid these):

- `./mullvad_tailscale.conf` (this runs it with shell; wrong interpreter)
- `sudo nft mullvad_tailscale.conf` (missing `-f`)
- `sudo nft delete rule ... ip daddr ...` (fails for existing inserted rules; use handle)

Service diagnostics:

```bash
systemctl status mullvad-tailscale-fix.service --no-pager
journalctl -b --no-pager -u mullvad-tailscale-fix.service
journalctl -b --no-pager -t mullvad-tailscale-fix
```

## RFKill guard

Use this when Wi-Fi gets randomly soft-blocked by `KEY_RFKILL` events.

Files in this repo:

- `apps/.local/bin/rfkill-guard`
- `apps/.local/bin/rfkill-airplane`
- `apps/.config/systemd/user/rfkill-guard.service`

Install as symlinks:

```bash
chmod +x /home/end/projects/dotfiles/apps/.local/bin/rfkill-guard /home/end/projects/dotfiles/apps/.local/bin/rfkill-airplane
ln -sfn /home/end/projects/dotfiles/apps/.local/bin/rfkill-guard /home/end/.local/bin/rfkill-guard
ln -sfn /home/end/projects/dotfiles/apps/.local/bin/rfkill-airplane /home/end/.local/bin/rfkill-airplane
ln -sfn /home/end/projects/dotfiles/apps/.config/systemd/user/rfkill-guard.service /home/end/.config/systemd/user/rfkill-guard.service
systemctl --user daemon-reload
systemctl --user enable --now rfkill-guard.service
```

Useful commands:

```bash
/home/end/.local/bin/rfkill-guard status
/home/end/.local/bin/rfkill-guard pause
/home/end/.local/bin/rfkill-guard resume
journalctl --user -b --no-pager -u rfkill-guard.service
```

## Suspend / Hibernate behavior

Goal:

- quick wake when you close the lid (suspend first)
- auto-hibernate later (3h timer or low battery)
- force low-battery critical action to hibernate (not generic sleep)

### logind lid policy

`/etc/systemd/logind.conf.d/90-lid-s2h.conf`

```ini
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
HandleLidSwitchDocked=ignore
```

### systemd sleep policy

`/etc/systemd/sleep.conf.d/90-s2h.conf`

```ini
[Sleep]
AllowSuspendThenHibernate=yes
HibernateDelaySec=3h
HibernateOnACPower=no
SuspendEstimationSec=10min
```

### UPower critical battery action

`/etc/UPower/UPower.conf`

```ini
UsePercentageForPolicy=true
PercentageLow=20.0
PercentageCritical=5.0
PercentageAction=5.0
CriticalPowerAction=Hibernate
```

Apply changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart upower.service
sudo reboot
```

Verify:

```bash
upower -d | rg -i 'critical-action|percentage'
systemd-analyze cat-config systemd/logind.conf | rg HandleLidSwitch
systemd-analyze cat-config systemd/sleep.conf | rg -E 'AllowSuspendThenHibernate|HibernateDelaySec|HibernateOnACPower|SuspendEstimationSec'
```

If low battery still reaches lock/suspend too late, raise `PercentageAction` to `6.0` or `7.0`.

## RFKill guard (random Wi-Fi airplane toggles)

Context:

- Framework keyboard/numpad radio-control inputs and Vicinae virtual keyboard devices can emit rfkill events.
- When that happens, NetworkManager reports: `rfkill: Wi-Fi now disabled by radio killswitch`.

Files in this repo:

- `apps/.local/bin/rfkill-guard`
- `apps/.local/bin/rfkill-airplane`
- `apps/.config/systemd/user/rfkill-guard.service`
- `apps/.config/niri/config.kdl` (`XF86WLAN` / `XF86RFKill` bind to wrapper)

Install/update:

```bash
install -Dm755 /home/end/projects/dotfiles/apps/.local/bin/rfkill-guard /home/end/.local/bin/rfkill-guard
install -Dm755 /home/end/projects/dotfiles/apps/.local/bin/rfkill-airplane /home/end/.local/bin/rfkill-airplane
install -Dm644 /home/end/projects/dotfiles/apps/.config/systemd/user/rfkill-guard.service /home/end/.config/systemd/user/rfkill-guard.service

systemctl --user daemon-reload
systemctl --user enable --now rfkill-guard.service
```

Useful commands:

```bash
systemctl --user status rfkill-guard.service --no-pager
journalctl --user -b --no-pager -u rfkill-guard.service

# Manual control
/home/end/.local/bin/rfkill-guard status
/home/end/.local/bin/rfkill-guard pause
/home/end/.local/bin/rfkill-guard resume
```
