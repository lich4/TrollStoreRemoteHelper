# TrollStoreRemoteHelper

## 基本用法

&emsp;&emsp;TrollStore需要拷贝IPA到设备然后手动安装，比较麻烦。本工具通过简单的配置XCode就可以自动远程安装IPA。
这里以TrollStoreRemoteHelperDemo为例展示操作步骤：

1. 用TrollStore安装TrollStoreRemoteHelper.tipa并启动。获取监听IP

&emsp;&emsp;有朋友用隔空投送可以直接安装tipa, 如果不成功可以尝试如下步骤:
* 从github release获取tipa下载地址, 如[https://github.com/lich4/TrollStoreRemoteHelper/releases/download/1.3/TrollStoreRemoteHelper.tipa]
* PC端将该url输入网络剪贴板[https://netcut.cn/], 手机Safari打开网络剪贴板获取到url
* 复制url, 在TrollStore中选择URL方式安装
   
```txt
2023-12-29 12:54:41 helper find:/varicontainers/Bundle/Applicatice/2FA0E066-E4F1-468D-9CC6-
5DCA6A21226F/TrollStore.app/trollstorehelper
2023-12-29 12:54:41 TrollStoreRemoteHelper pid=1037 listen=192.168.0.141:1222
```

2. TrollStoreRemoteHelperDemo为已经配置好的测试项目，如果自行开发需要操作如下(假定工程名为`TEST`)

* 配置工程目录中的文件`TEST.entitlements`及`md-trollstore`
* "Build Settings" - "Add User-Defined Settings"  
```txt
CODE_SIGNING_ALLOWED设置为NO  
TROLLSTORE_DEVICE_IP设置为监听IP,如果为空则不进行远程安装
```  
* "Build Phases"中添加"Run Script"
```txt
$PWD/md-trollstore
```

3. ~~保持TrollStoreRemoteHelper在前台~~(1.2版本更新:实现后台安装)，执行XCode编译，此时自动远程安装到设备

```txt
2023-12-29 12:55:27 download success:/var/mobile/Containers/Data/Application/62749933-F4C1-4C2D-AF45-
ECFFE318F937/tmp/TrollStoreRemoteHelperDemo.ipa
2023-12-29 12:55:28 install succes TrollStoreRemoteHelperDemo.ipa
2023-12-29 12:55:55 download success:/var/mobile/Containers/Data/Application/62749933-F4C1-4C2D-AF45-
ECFFE318F937/tmp/TroIStoreRemoteHelperDemo.ipa
2023-12-29 12:55:56 install success TrollStoreRemoteHelperDemo.ipa
```

&emsp;&emsp;这里解决了XCode自动安装TrollStore App的问题，如果要调试可以在越狱环境下使用我的另一个项目`https://github.com/lich4/debugserver_azj`


## 远程shell

&emsp;&emsp;为便于在非越狱下进行基本操作,本工具提供非越狱ssh功能

```txt
系统自带: df ps mount umount
ldid, opainject, otool, trollstorehelper, fastPathSign
+
[ b2sum base32 base64 basename basenc cat chcon chgrp chmod chown chroot cksum comm cp csplit cut 
date dcgen dd dir dircolors dirname du echo env expand expr factor false fmt fold 
getlimits ginstall groups head hostid id join kill link ln logname ls 
make-prime-list md5sum mkdir mkfifo mknod mktemp mv nice nl nohup nproc numfmt od 
paste pathchk pinky pr printenv printf ptx pwd readlink realpath rm rmdir runcon 
seq sha1sum sha224sum sha256sum sha384sum sha512sum shred shuf sleep sort split stat stdbuf stty 
sum sync tac tail tee test timeout touch tr true truncate tsort tty 
uname unexpand uniq unlink uptime users vdir wc who whoami yes
+ 
find, xargs, grep, uname, killall, dropbear, vim, ssh, scp, launchctl, which, ping, ifconfig 
```

helper端口绑定1222; ssh端口绑定1223 密码alpine, 无需越狱即可使用ssh

![](https://raw.githubusercontent.com/lich4/TrollStoreRemoteHelper/main/screenshot.png)

## 杂记

posix_spawn返回错误:
```txt
85      EBADEXEC    entitlement去掉com.apple.private.skip-library-validation
86      EBADARCH    去除arm64e,只保留arm64
```

