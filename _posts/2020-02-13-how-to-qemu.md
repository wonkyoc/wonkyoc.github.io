---
layout: post
title: How to use QEMU with gdb
date: 2020-02-29
categories: [Manual]
tags: []
last_modified_at: 2020-02-29
---

As a non-English speaker, using two different languages in vim is quite hard. 
Unlike this article, if I write it down as Korean, I have to change language everytime I want to use English and this is pain-in-the-neck.
(It is true that using different editors such as Atom or VS code is alternative but you know changing language whilst writing something is always annoying.)
So, from this article, I decided to do this as English for my conveninence and global friends.

Anyway, today I want to talk about how to use QEMU and how to debug kerenl within the QEMU.
There are a lot of articles for this purpose but none of them are not satisfactory although some of them are really helpful.
Plus, I have not summarized or written something such a long time so I think that this could be the good start point to write down my thought in the Internet.

# QEMU & KVM
Before playing a DEMO I would like to breifly explain what is QEMU and what is KVM, which is quite crucial thing to know rather to skip.

**QEMU** is a system emulator which can emulate many architectures (e.g. ARM or PowerPC).
We can call it another name, Type-2 hypervisor like Virtualbox. 
**KVM** was actually a fork of QEMU (currently merged into kernel mainline and QEMU mainline) and this can be categorized as Type-1 Hypervisor or Full-virutalization. 
(I am not going to explain the detail of virtualization. This is way too beyond this topic.)

The main difference is that KVM can do hardware virutalization while QEMU cannot.
QEMU runs independently without any KVM support but it is slow.
So QEMU uses KVM to accelerate the emulation if the host has hardware virtualization extenstion. 
(e.g. Intel VT/VT-d, AMD-V).

# Environment I am using
{% highlight shell %}
$ lsb_release -a
Distributor ID: Ubuntu
Description:    Ubuntu 18.04.4 LTS
Release:        18.04
Codename:       bionic

$ uname -r
5.3.0-40-generic
{% endhighlight %}

# Install QEMU
If you want to install QEMU by building and installing, you should go to the QEMU mirror site.
I rather choose to install it through `apt` for conveniency.

{% highlight shell %}
$ sudo apt install qemu
$ qemu-system-x86_64 -version
QEMU emulator version 2.11.1(Debian 1:2.11+dfsg-1ubuntu7.22)
Copyright (c) 2003-2017 Fabrice Bellard and the QEMU Project developers
{% endhighlight %}

## Might be a tip
Not all of them but some of your computers might complain that you have no permission
to run `qemu-system-x86_64`. In that case, using simply `sudo` could be the panacea but 
we all know that using `sudo` has a risk.

Alternatively, adding yourself to kvm group could be a solution.
{% highlight shell %}
$ sudo adduser $USER kvm
{% endhighlight %}

> From this part, many parts come from [mgals's awesome blog].
There are few commands which are not self-explanatory so I will add some comments.

# Preparation: Kernel & Busybox
Firstly, make a working directory for our main purpose and
install Busybox and Linux kernel latest version (or your custom version) in the directory.
I choose `5.4.15` which is the latest and stable version at this moment.

{% highlight shell %}
$ TOP=$HOME/teeny-linux
$ mkdir $TOP && cd $TOP
$ curl https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.4.23.tar.xz | tar xJf -
$ curl https://busybox.net/downloads/busybox-1.31.1.tar.bz2 | tar xjf -
{% endhighlight %}

# Busybox Userland
After installation, the first thing to do is to make a filesystem for kernel.
When the system boots at first, the system needs to know how to boot kernel.
This can be done by `initramfs`. We will make this using `cpio` and busybox.

{% highlight shell %}
$ cd $TOP/busybox-1.31.1
$ mkdir -pv ../obj/busybox-x86
$ make O=../obj/busybox-86 defconfig
{% endhighlight %}

If you have ever compiled kernel before, you would know what `make menuconfig` or 
`make defconfig` does. `O=/path` is simply placing build output in `/path`.

{% highlight shell %}
$ make O=../obj/busybox-x86 menuconfig
{% endhighlight %}

and find `Build BusyBox as a static binary` or you can find typing `/` and then `static`.
(Really need to know what the static binary does)
{% highlight shell %}
-> Settings
    -> Build Options
    [ ] Build BusyBox as a static binary (no shared libs)
{% endhighlight %}

If you finish all these things, now then you are ready to install it and do several post-jobs.
{% highlight shell %}
$ cd $TOP/obj/busybox-x86
$ make -j{# of core}    # mine is 8
$ make install
{% endhighlight %}

And then, copy all files to the initramfs directory.

{% highlight shell %}
$ mkdir -pv $TOP/initramfs/x86-busybox
$ cd $TOP/initramfs/x86-busybox
$ mkdir -pv {bin,sbin,etc,proc,sys,usr/{bin,sbin}}
$ cp -av $TOP/obj/busybox-x86/_install/* .
{% endhighlight %}

So far, you can see a similar file structure with your host.

{% highlight shell %}
$ pwd
$HOME/teeny-linux/initramfs/x86-busybox/
$ ls
bin etc linuxrc proc sbin sys usr
{% endhighlight %}

Before wrapping all this up, we should make a script that I need you to do this, kernel.
{% highlight shell %}
$ vim init
{% endhighlight %}

{% highlight bash %}
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys

echo -e "\nBoot took $(cut -d' ' -f1 /proc/uptime) seconds\n"
exec /bin/sh
{% endhighlight %}

{% highlight shell %}
$ chmod +x init
{% endhighlight %}

Finally, pacaking all this into one file.

{% highlight shell %}
$ find . -print0 \
    | cpio --null -ov --format=newc \
    | gzip -9 > $TOP/obj/initramfs-busybox-x86.cpio.gz
{% endhighlight %}

For an astute reader, I add some manual for each command option.

{% highlight shell %}
$ man find
-print0
    True; print the full file name on the standard output, followed by a null character
$ man cpio
-0, --null
    Filenames in the list are delimited by null chracters instead of newlines.
$ man gzip
-9 --best
    indicates the slowest compression method (best compression).
{% endhighlight %}

# Linux Kernel
Now, it is time to build the kernel and configure it. It is easy but the only difference that
I usually do is to make outputs to other directory. Every step is as same as Busybox's.
{% highlight shell %}
$ cd $TOP/linux-5.4.15
$ make O=../obj/linux-x86-basic x86_64_defconfig
$ make O=../obj/linux-x86-basic kvmconfig
$ make O=../obj/linux-x86-basic -j{# of core}
{% endhighlight %}

# Run QEMU
Everything sets up. We are now ready to run QEMU.
{% highlight shell %}
$ cd $TOP
$ qemu-system-x86_64 \
    -kernel obj/linux-x86-basic/arch/x86_64/boot/bzImage \
    -initrd obj/initramfs-busybox-x86.cpio.gz \
    -nographic -append "console=ttyS0" -enable-kvm
{% endhighlight %}

If you run this command, you would see the below terminal 
and this means that you run successfully QEMU with your kernel version.
{% highlight shell %}
...
[    0.799535] Write protecting the kernel read-only data: 20480k
[    0.800722] Freeing unused kernel image memory: 2004K
[    0.801173] Freeing unused kernel image memory: 808K
[    0.801555] Run /init as init process

Boot took 0.75 seconds

/bin/sh: can't access tty; job control turned off
/ # [    1.198878] random: fast init done
[    1.408167] input: ImExPS/2 Generic Explorer Mouse as /devices/platform/i8042/serio1/input/input3
{% endhighlight %}

## Few tips
If you want to get out of this kernel, you should type `Ctrl+a` and then press `x` button.
Or, if you want to only exit from the kernel not the entire QEMU system, type `Ctrl-a` and 
press `c` button. Then you would be able to see that only the qemu command line.
If you want to exit in this state, type `quit`. `help` might give several options that you need.

{% highlight shell %}
(qemu) 
{% endhighlight %}

Instead of using built-in key press, you can also use monitoring feature of QEMU.
{% highlight shell %}
# a client terminal
$ qemu-system-x86_64 \
    -kernel obj/linux-x86-basic/arch/x86_64/boot/bzImage \
    -initrd obj/initramfs-busybox-x86.cpio.gz \
    -nographic -append "console=ttyS0" -enable-kvm
    -monitor telnet::45454,server,nowait -serial mon:stdio
{% endhighlight %}

{% highlight shell %}
# a host terminal
$ telnet localhost 45454
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
QEMU 2.11.1 monitor - type 'help' for more information
(qemu)
{% endhighlight %}
This monotoring feature is actually useful for me because I am using `tmux` and my prefix bound to `Ctrl-a`
So, everytime I try to quit QEMU tmux gets this interrupt, QEMU does not have any signal from it.

You may want to see [this stackoverflow answer]

# QEMU with GDB
For now, we are almost close to the end. Finally, we need to set up GDB and this is pretty much easy.
Like `-monitor` we need two terminal windows for a client and a host.
The only thing to add is to put `-s` in QEMU command.
{% highlight shell %}
$ man qemu-system-x86_64
...
-s Shorthand for -gdb tcp::1234, i.e. open a gdbserver on TCP port 1234.
{% endhighlight %}

{% highlight shell %}
# a client terminal
$ qemu-system-x86_64 \
    -s \
    -kernel obj/linux-x86-basic/arch/x86_64/boot/bzImage \
    -initrd obj/initramfs-busybox-x86.cpio.gz \
    -nographic -append "console=ttyS0" -enable-kvm
{% endhighlight %}

{% highlight shell %}
# a host terminal
$ cd $TOP/obj/linux-x86-basic
$ gdb
...
(gdb) set architecture i386:x86-64
(gdb) file vmlinux
(gdb) target remote 127.0.0.1:1234
Remote debugging using 127.0.0.1:1234
0xffffffffb8eb3950 in ?? ()
(gdb)
{% endhighlight %}

You can find more details in [Stefan Hajnoczi's slide]

### Reference
* [What Is the Difference between QEMU and KVM?](https://www.packetflow.co.uk/what-is-the-difference-between-qemu-and-kvm/)
* [Stefan Hajnoczi's blog](http://blog.vmsplice.net/)

[Stefan Hajnoczi's slide]:https://vmsplice.net/~stefan/stefanha-kernel-recipes-2015.pdf
[this stackoverflow answer]:https://superuser.com/questions/1087859/how-to-quit-the-qemu-monitor-when-not-using-a-gui
[mgals's awesome blog]:http://mgalgs.github.io/2015/05/16/how-to-build-a-custom-linux-kernel-for-qemu-2015-edition.html
[Quora answer]:https://www.quora.com/Virtualization-What-is-the-difference-between-KVM-and-QEMU
