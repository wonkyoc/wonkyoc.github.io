---
layout: post
title: How to use QEMU
date: 2020-02-13
categories: [Manual]
tags: []
last_modified_at: 2020-02-13
---

### Install QEMU
{% highlight shell %}
$ sudo apt install qemu
$ qemu-system-x86_64 -version
QEMU emulator version 2.11.1(Debian 1:2.11+dfsg-1ubuntu7.22)
Copyright (c) 2003-2017 Fabrice Bellard and the QEMU Project developers
{% endhighlight %}

**Download, build kernel**  
See [How to Kernel]({{ site.baseurl }}/how-to-kernel)

**다운로드한 kernel dir 에서 config 확인하기**
{% highlight shell %}
# 글쓴이 5.4.15
$ cat linux-5.4.15/.config
...
CONFIG_DEBUG_INFO=y
# CONFIG_DEBUG_RODATA is not set
CONFIG_FRAME_POINTER=y
CONFIG_KGDB=y
CONFIG_KGDB_SERIAL_CONSOLE=y
...
{% endhighlight %}


#### QEMU side
{% highlight shell %}
$ qemu-system-x86_64 -enable-vkm -m 1024 -kernel /boot/vmlinuz-5.4.15 \
    -initrd /boot/initrd.img-5.4.15 \
    -append 'kgdbwait kgdboc=ttyS0,115200' \
    -serial tcp::1234,server,nowait
{% endhighlight %}

#### gdb side
{% highlight shell %}
$ gdb -ex 'file vmlinux' -ex 'target remote localhost:1234'
{% endhighlight %}






### Reference
* [Speed up your kernel development cycle with QEMU](https://vmsplice.net/~stefan/stefanha-kernel-recipes-2015.pdf)
* []http://landley.net/kdocs/Documentation/DocBook/xhtml-nochunks/kgdb.html
