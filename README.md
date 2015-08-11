# resflash

#### Resilient OpenBSD images for flash memory

Resflash is a tool for building OpenBSD images for embedded and cloud systems in a reproducible way. Resflash exclusively uses read-only and memory-backed filesystems, and because the partitions are only written to during system upgrades (or as otherwise configured), filesystems are not subject to corruption or fsck due to power loss - and even cheap flash drives can last virtually forever. Resflash images can be written to any bootable flash media, such as USB drives, SD cards, or Compact Flash, or even conventional hard drives or SSDs. Resflash was written from scratch, with inspiration drawn from [NanoBSD](https://www.freebsd.org/doc/en_US.ISO8859-1/articles/nanobsd/) and [flashrd](http://www.nmedia.net/flashrd/).

## Features

- Read-only filesystems on all disk-backed partitions. Power can be safely lost at any time. 
- An easy, one-step upgrade process.
- Persistent configuration changes are possible by a /cfg partition, stored either manually or automatically on shutdown, and re-populated on boot.
- Full package support using the standard pkg_* tools or at build time.
- Easy failover to the previous working image in the event of a boot failure (console access required).
- System requirements comparable to that of OpenBSD (1 GB flash drive recommended).
- Supports amd64 and i386.

## Features unique to resflash

- A one-command build process, with no configuration file or sector calculations required.
- An unmodified OpenBSD operating system - no custom kernels, no ramdisks.
- Images can be built using only the OpenBSD distribution sets, no compiler or OpenBSD source is required.
- Branch-agnostic: Build images using -current snapshots on -stable.
- Arch-agnostic: Build i386 images on amd64, or vice-versa. *Note: Cross-arch builds do not support package installation at build time.*
- System upgrades update the [MBR](http://www.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man8/fdisk.8), [biosboot(8)](http://www.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man8/amd64/biosboot.8), and [boot(8)](http://www.openbsd.org/cgi-bin/man.cgi/OpenBSD-current/man8/amd64/boot.8).
- Modified files in /etc or /var can be saved manually or automatically on shutdown - either en masse or by directory or file (i.e. `.`, `/etc/ssh`, `/var/db/dhcpd.leases`)
- Builds with ksh or Bash (but why?).

## How does it work?

Resflash images contain two main data partitions, one active and one inactive. During the upgrade process, the inactive partition is updated, tested, and set active for the next boot. A /cfg partition can be used to store modifications from the tmpfs filesystems (/etc and /var) and are overlaid at boot time. A small /mbr partition is used to maintain the boot code.

## Coverage

- [BSD Now - Episode 099: BSD Gnow](http://www.bsdnow.tv/episodes/2015_07_22-bsd_gnow)

## Downloads

- The latest stable source can be found in the [resflash master branch](https://github.com/bconway/resflash) on GitHub. Resflash always supports the two currently-supported releases of OpenBSD, starting with 5.7. A [.zip download](https://github.com/bconway/resflash/archive/master.zip) is also available.
- Premade -stable images are available at [http://stable.rcesoftware.com/pub/resflash](http://stable.rcesoftware.com/pub/resflash). Versions are available for amd64 and i386, each with VGA or com0 console. Both .img and .fs files, **for installs and upgrades**, are available.
- Sets from the -stable branch are available at [http://stable.rcesoftware.com/pub/OpenBSD](http://stable.rcesoftware.com/pub/OpenBSD) for amd64 and i386. These are not (yet) built in an automated fashion, but should be updated shortly after an errata notice.

## Usage

1. Create an OpenBSD base directory with a minimum of the following:

  - `bsd` (sp or mp supported)
  - `baseXY.tgz`
  - `(base dir)/usr/share/sysmerge/etc.tgz`

  Sets **must** be unpacked as **root** using `tar zxfph set.tgz`.

2. `./build_resflash.sh [-p packages_dir] [-s com0_console_speed] img_size_in_mb openbsd_base_dir`
3. Write the .img file (not the .fs file) to the drive of your choice: `dd if=resflash-amd64-com0-115200-20150720_0257.img of=/dev/rsd3c bs=1m`

Sample output:

```
resflash 5.8.0

Validating OpenBSD base dir: /usr/local/rdest...
Creating disk image: resflash-amd64-com0-115200-20150810_0231.img...
Creating filesystem image: resflash-amd64-com0-115200-20150810_0231.fs...
Populating filesystem and configuring fstab...
Running fw_update...
Installing packages...
Writing filesystem to image and calculating checksum...
Build complete!

File sizes:
306M    resflash-amd64-com0-115200-20150810_0231.fs
953M    resflash-amd64-com0-115200-20150810_0231.img
Disk usage:
237M    resflash-amd64-com0-115200-20150810_0231.fs
310M    resflash-amd64-com0-115200-20150810_0231.img
```

## Upgrades

Unlike the initial installation, upgrades use .fs filesystem files. Upgrades take place by piping the .fs file through the /resflash/upgrade.sh script. This can be accomplished in many ways:

- The less secure, trusted LAN-only way:
  1. On the system to be upgraded, run as **root**: `nc -l 1234 | /resflash/upgrade.sh`
  2. On the build system, run: `nc -N 10.0.x.y 1234 < resflash-amd64-com0-115200-20150720_0257.fs`
  3. Review the output, confirm the filesystem checksum, and reboot.
- The more secure, requiring root ssh login way:
  1. On the build system, connect to the system to be upgraded: `ssh -C root@10.0.x.y /resflash/upgrade.sh < resflash-amd64-com0-115200-20150720_0257.fs`
  2. Review the output, confirm the filesystem checksum, and reboot.

Sample output:

```
Writing filesystem to inactive partition...
942a56a94525c532a7b5575b0ccda81bd9910e22601170bf83a03a6f2425030c7577a5020a11cba6
9c5c5e8f5f093f8c7b1c0f426c04d1fbd2f0767772e74f1c
Checking filesystem...
/dev/rwd0d: 12268 files, 152563 used, 37038 free (238 frags, 4600 blocks, 0.1% f
ragmentation)
Updating fstab...
Updating MBR, biosboot(8), and boot(8)...
Everything looks good, setting the new partition active...
Upgrade complete!
```

## Other build tools

- `mount_resflash.sh` - Mount all the partitions of a resflash .img or .fs file. This is useful for scripting configuration after a build.
- `umount_resflash.sh` - Unmount a mounted resflash .img or .fs file.

## Host tools

- `/etc/resflash.conf` - Optional configuration file for automating backup of files in /etc or /var on shutdown. Consult the file for available options.
- `/resflash/save_ssh_ike_keys.sh` - Save SSH and IKE keys to /cfg.
- `/resflash/set_root_pass.sh` - Update root password and save necessary password db files to /cfg.
 
## Problems?

Resflash is not a supported OpenBSD configuration. Please do not email misc@ asking for help. If you have a question or a bug to report, please [post to the mailing list](http://www.freelists.org/list/resflash), [submit an issue](https://github.com/bconway/resflash/issues) on GitHub, or [email me](mailto:bconway-at-rcesoftware-dot-com) directly.

## Support OpenBSD

This project would not be possible without the work of the fine folks at OpenBSD. Please support them with a [donation](http://www.openbsd.org/donations.html) or [purchase](http://www.openbsd.org/orders.html).

## FAQ

#### What is the root password for the premade images?

As resflash uses an unmodified OpenBSD operating system, there is no root password by default. Hit enter at the password prompt to log in as root. You will need to set a root password before logging in remotely via SSH.

#### What is the difference between the .img and .fs files?

The .img files are disk images, including MBR partition tables, that are used for initial installation to a flash drive. The .fs files are filesystems that are used for in-place upgrades by `/resflash/upgrade.sh`.

#### How do I use the /cfg partition?

The /cfg partition is unmounted in most situations. Files are saved either manually or automatically on shutdown according to `/etc/resflash.conf`. To manually store a file, mount /cfg and then copy any file you want re-populated on boot to /cfg/etc or /cfg/var, retaining the directory structure (i.e. `/cfg/etc/hostname.em0` or `/cfg/etc/ssh/sshd_config`), followed by unmounting /cfg. You can also run `/resflash/resflash.save` manually to save configured files in advance of shutdown.

#### What about LBA and CHS?

Resflash requires an LBA-aware BIOS. CHS numbers have been bogus for [20 years](https://en.wikipedia.org/wiki/Logical_block_addressing), and I don't have the hardware for - or much interest in - supporting them. **Make sure to set your Alix board to LBA mode.** If you have a use case for a CHS-only device that needs supporting, I'd be interesting in [hearing](mailto:bconway-at-rcesoftware-dot-com) about it.

#### Help! I ran the upgrade and now it won't boot. How do I failover to the previous version?

At the OpenBSD boot prompt, enter `set device hd0d` and press enter, assuming that the 'e' partition is your upgraded partition that is failing to boot. If 'd' is failing, set it to hd0e. Before doing any diagnosis on your failed upgrade, you will want to mount /mbr and edit /mbr/etc/boot.conf to point to the working boot device.

#### How do I customize my build? Is there a tool for that?

No additional configuration tools are planned for resflash at this time. You are encouraged to use the (u)mount_resflash.sh tools to script your own configuration. Consult the resflash source for some ways to modify mounted resflash filesystems or make use of chroot where simple file manipulation isn't sufficient. In the future, I will probably open source some sample configuration scripts that I use.

#### Should I customize the .img file prior to writing to disk, or via /cfg?

There is no wrong answer here. If you're scripting your builds, it probably makes sense to use the (u)mount_resflash.sh tools to make all your changes to the .img or .fs directly, and then use /cfg exclusively for runtime files (i.e. `/var/db/host.random`). If you're using resflash for a single system, it's perfectly reasonable to save things like `myname` or `hostname.em0` in /cfg/etc.

