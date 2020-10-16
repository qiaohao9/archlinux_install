![](https://raw.githubusercontent.com/vastpeng/pic-storage/master/ND6Zjw.png)

# What's this?

ArchLinux 自动安装脚本（UI is inspired by [aui](https://github.com/helmuthdu/aui))。

使用该脚本，只需要简单的几步设置，即可自动安装完成基础 Arch Linux  系统，避免了繁琐的命令输入过程。

# How to use it?

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tinyratp/archlinux_install/master/base_install.sh)"
```

# base_install Scripts

* Configure Mirrorlist
* Configure Lanuages
* Configure Timezone
* Set Hostname
* Set Root Password / Login User
* Format Devices / Create Partions
* Install System Base
* Install bootloader

# extra_install Scripts(TODO)

* Configure Shadowsocks-libev & Privoxy(For [GFW](https://en.wikipedia.org/wiki/Great_Firewall))
* Configure Desktop(ex: i3wm)
* Configure Fonts(ex: Unicode Chinese)
* Downloading Common Apps


# What's next?

- [x] User-interface
- [x] make array to set
- [ ] Support LVM
- [ ] Select filesystem
- [ ] Support install extra apps
