---
layout: post
title: 这些Window们 --- 前言
description: 
author: 电解质
date: 2018-03-23
share: true
comments: true
tag:
- Android Senior Engineer
---
* TOC
{:toc}
## *1.Summary*{:.header2-font}
&emsp;&emsp;Window在Android中是非常重要的，围绕其实现的系统也是非常的复杂，但是Android团队通过封装其Framework层接口，向外提供了WindowManager，能让开发者简单而又快速的add自己的view。不过对于想更加深入理解像应用窗口、子窗口、系统窗口如何被coding出来的程序员来说，阅读Activity、Dialog、Toast等是非常有用的。

## *2.Introduction*{:.header2-font}


### *type*{:.header3-font}

&emsp;&emsp;首先要知道Android中窗口的分布是按照z-order的，也就是指向屏幕外的z轴。z-order值越大，就会覆盖住值越小的，从而也就更能被我们看到。这些值被按照窗口类型分为：应用窗口（1-99）、子窗口（1000 - 1999）、系统窗口（2000-2999）

<!-- ![]({{site.asseturl}}/2018-03-23/2018-03-23-Window-Zorder.png) -->
![]({{site.asseturl}}/2018-03-23/2018-03-23-Window-types.png)
<!-- 
|应用窗口 | 子窗口 |系统窗口|
|---|---|----|
|TYPE_BASE_APPLICATION|TYPE_APPLICATION_PANEL |TYPE_STATUS_BAR|
|TYPE_APPLICATION|TYPE_APPLICATION_MEDIA |TYPE_SEARCH_BAR|
|TYPE_APPLICATION_STARTING|TYPE_APPLICATION_SUB_PANEL|TYPE_PHONE|
|TYPE_DRAWN_APPLICATION|TYPE_APPLICATION_ATTACHED_DIALOG|TYPE_SYSTEM_ALERT|
      | |TYPE_APPLICATION_MEDIA_OVERLAY  |TYPE_KEYGUARD |
       | |TYPE_APPLICATION_ABOVE_SUB_PANEL |TYPE_TOAST|
       |                             ||TYPE_SYSTEM_OVERLAY|
       |                          ||TYPE_PRIORITY_PHONE|
       |                             ||TYPE_SYSTEM_DIALOG|
       |                            ||TYPE_KEYGUARD_DIALOG|
       |                             ||TYPE_SYSTEM_ERROR|
       |                             ||TYPE_INPUT_METHOD|
       |                             || TYPE_INPUT_METHOD_DIALOG|
       |                             ||TYPE_WALLPAPER|
       |                             ||TYPE_STATUS_BAR_PANEL|
       |                             ||TYPE_SECURE_SYSTEM_OVERLAY|
       |                             ||TYPE_DRAG|
       |                             ||TYPE_STATUS_BAR_SUB_PANEL|
       |                             ||TYPE_POINTER|
       |                             ||TYPE_NAVIGATION_BAR|
       |                             ||TYPE_VOLUME_OVERLAY|
       |                             ||TYPE_BOOT_PROGRESS|
       |                             ||TYPE_INPUT_CONSUMER|
       |                             ||TYPE_DREAM|
       |                             ||TYPE_NAVIGATION_BAR_PANEL|
       |                             ||TYPE_DISPLAY_OVERLAY|
       |                             ||TYPE_MAGNIFICATION_OVERLAY|
       |                             ||TYPE_PRIVATE_PRESENTATION|
       |                             ||TYPE_VOICE_INTERACTION|
       |                             ||TYPE_ACCESSIBILITY_OVERLAY|
       |                             ||TYPE_VOICE_INTERACTION_STARTING|
       |                             ||TYPE_DOCK_DIVIDER|
       |                             ||TYPE_QS_DIALOG|
       |                             ||TYPE_SCREENSHOT|
       |                             ||TYPE_PRESENTATION|
       |                             ||TYPE_APPLICATION_OVERLAY|
{:.inner-borders} -->


### *flag*{:.header3-font}
&emsp;&emsp;其次，你还可以控制窗口的flag。是否焦点、是否允许在锁屏显示、是否全屏等。

![]({{site.asseturl}}/2018-03-23/2018-03-23-Window-flags.png)


### *soft input mode*{:.header3-font}
还有控制ime的参数

![]({{site.asseturl}}/2018-03-23/2018-03-23-Window-softinput.png)


当然了你还可以设置窗口的其他属性，比如宽高、透明度、gravity、margin等
