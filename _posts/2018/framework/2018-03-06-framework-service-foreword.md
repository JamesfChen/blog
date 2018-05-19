---
layout: post
title: Framework层的服务 --- 前言
description: 
author: 电解质
date: 2018-03-06
share: true
comments: true
tag:
- Android Senior Engineer
---
<!-- * TOC
{:toc} -->
## *1.Summary*{:.header2-font}

&emsp;&emsp;开头说一下市场上关于这种文章已经有很多了，为什么要写这个系列的文章。这要说道我刚毕业时，主要从事Android手机ROM定制的工作，是一名Android ROM开发者,相对于App开发者对于Framework层的了解也会多一点，但是如今成为了一个App开发者。而站在App开发者的角度去思考，App开发者需要知道Framework层的哪些知识呢 ？网上的文章要么太深入（像老罗，gityuan、邓凡平这样的ROM开发者），要么太片面（都是从某一个API切入），所以我的经历加上我的思考产生了这个系列的文章，此原因之一；其二，看了许多Framework层源码而没有进行总结就会像流水一样，转瞬即逝。基于这两点这个系列文章主要是引导开发者思考Framework层的AMS、PKMS、WMS的设计，唯有把握了全局再去阅读具体的实现，才能体会到Android团队当初在code Framework层代码时的想法，才能提高自身的技术水平和眼界。所以啊，对于一个Android高级工程师来说，是需要将自己的眼界拉到全局，用一种架构的心态去思考，而不是只专注埋头code某块功能的代码。

## *2.Introduction*{:.header2-font}

&emsp;&emsp;我们都知道kernel的内核空间运行之后会启动用户空间的init进程，进程id为0，也就是天字一号的地位。之后init进程会fork出zygote进程(应用程序名/system/bin/app_process,源码文件frameworks/base/cmds/app_process/app_main.cpp)用于孵化上层应用和服务，比如SystemServer进程。而SystemServer进程，初始化过程中会附带启动ActivityManagerService(AMS)、PackageManagerService(PKMS)、WindowManagerService(WMS)等系统服务，并且在主线程开启一个Looper，接收其他线程的消息，从而实现线程通讯。

重要分包
```
frameworks/base/services/java/com/android/server/SystemServer.java

frameworks/base/services/core/java/com/android/server/am/ActivityManagerService.java

frameworks/base/services/core/java/com/android/server/pm/PackageManagerService.java

frameworks/base/services/core/java/com/android/server/wm/WindowManagerService.java
```
&emsp;&emsp;看完上面的分包后你应该能猜到一些规律了吧。
- am目录：AMS相关的目录，还包括ActivityStackSupervisor（ASS）、ActivityStack（AS）；
- pm目录：PKMS相关的目录，还包括PackageUsage；
- wm目录：WMS相关的目录，还包括Session、WindowState、WindowToken。

所以我们接下来就要围绕着AMS、PKMS、WMS这三个类来讲故事了。这里在插句话，当你学习完这三个service之后，类比其他的service(比如InputManagerService、PowerManagerService)也就能信手拈来，因为Framework层的service设计都差不多。先来张图大致熟悉一下整个Framework层的消息响应。

![]({{site.asseturl}}/2018-03-06/2018-03-06-Android-framework-architecture.png){: .center-image }

