# TrollStoreRemoteHelper

&emsp;&emsp;TrollStore需要拷贝IPA到设备然后手动安装，比较麻烦。本工具通过简单的配置XCode就可以自动远程安装IPA。
这里以TrollStoreRemoteHelperDemo为例展示操作步骤：

1. 用TrollStore安装TrollStoreRemoteHelper.ipa并启动。获取监听IP
   
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

3. 保持TrollStoreRemoteHelper在前台，执行XCode编译，此时自动远程安装到设备

```txt
2023-12-29 12:55:27 download success:/var/mobile/Containers/Data/Application/62749933-F4C1-4C2D-AF45-
ECFFE318F937/tmp/TrollStoreRemoteHelperDemo.ipa
2023-12-29 12:55:28 install succes TrollStoreRemoteHelperDemo.ipa
2023-12-29 12:55:55 download success:/var/mobile/Containers/Data/Application/62749933-F4C1-4C2D-AF45-
ECFFE318F937/tmp/TroIStoreRemoteHelperDemo.ipa
2023-12-29 12:55:56 install success TrollStoreRemoteHelperDemo.ipa
```

&emsp;&emsp;这里解决了XCode自动安装TrollStore App的问题，如果要调试可以在越狱环境下使用我的另一个项目`https://github.com/lich4/debugserver_azj`

[](https://raw.githubusercontent.com/lich4/TrollStoreRemoteHelper/main/screenshot.md)


