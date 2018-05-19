---
layout: post
title: Location系统 --- 架构概述
description: 讲解Location架构
author: 电解质
date: 2018-01-25 22:50:00
share: true
comments: true
tag:
- LBS
---
* TOC
{:toc}
## *1.Summary*{:.header2-font}
&emsp;&emsp;在上一篇我们讲了基本的使用，现在我们来看看Location架构是如何设计的。

## *2.About*{:.header2-font}
&emsp;&emsp;现如今原生的Location API已经很少人使用了，大都是集成第三方库，就连google也推荐使用他们家的Google Location Services API，所以对于原生的Location架构，我们可以当做学习资料来研究。如果你期望能参加LBS相关的开发工作，我相信通过研究源生的Location架构来提升自身技术是一个不错的选择。如何使用Google Location Services API可以看这一篇文章[Building Apps with Location & Maps](https://developer.android.com/training/building-location.html)，但是由于国内的特殊情况，所以催生了高德地图、腾讯地图等替代品。给了链接吧[高德定位sdk](http://lbs.amap.com/api/android-location-sdk/locationsummary)

## *3.Introduction*{:.header2-font}

![]({{site.asseturl}}/2018-01-25/2018-01-25-location-system-framework-architecture.png)

&emsp;&emsp;这个架构其实很好理解，应用层通过注册监听器来接受底层上报的定位数据，而定位数据的来源很多，可以是高精度的gps，可以network，也可以是passive。除了可以获取定位数据，还可以获取gps的测绘数据，以及gps其他信息。由于网络定位的优化算法都是服务厂商自己在搞，涉及到商业利益不便开源，所以我们在Android Location API中很少看到除了gps其他的定位服务API。Android团队为了保护服务厂商的利益，就像当时的HAL层出现一样，在Location的framework层提供了很多的XxxProxy类，然后通过ServiceWatcher连接到服务厂商自己的进程，从而规避了服务厂商暴露源码的风险。

&emsp;&emsp;不光是网络定位的实现交给了服务厂商，就连地理围栏、地理编码，也就是地图有关的都交给了服务厂商，所以我们在架构中看到了很多的XxxProxy类。唯一gps的源码我们是可以研究的。不过GnssLocationProvider类很值得我们去学习。

- 定义了一个内部类ProviderHandler用来处理底层上报的消息，
- 将协议方面的代码让Native层去实现
- 使用了[exponential backoff算法](https://en.wikipedia.org/wiki/Exponential_backoff)
- 注册了监听Geofence的接口

GnssLocationProvider类的这几个特质我们也可以在让网络定位的Provider拥有。

&emsp;&emsp;对于Native层其实没有什么好讲的，因为我之前也学习过Telephony的HAL层，深知如果是一名ROM开发者，那么学习HAL层是很有必要的，但是如果是一名App开发者，就没有必要了。不过对于framework-native层倒是可以学习一下，jni的开发模式也是需要学习的。我已经看了React Native的jni开发模式，有时间在把笔记整理好上传到博客。


## *4.Reference*{:.header2-font}
[Android 系统中 Location Service 的实现与架构](https://www.ibm.com/developerworks/cn/opensource/os-cn-android-location/)