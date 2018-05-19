---
layout: post
title: Framework层的服务 --- AMS管理四大组件
description: 图解四大组件
author: 电解质
date: 2018-03-15
tag:
- Android Senior Engineer
---
* TOC
{:toc}
## *1.Summary*{:.header2-font}
&emsp;&emsp;在了解了AMS的启动流程之后，我们就需要开始了解运行中的AMS是如何管理四大组件的。所以这一篇会通过图形的方式带领大家了解怎么管理的。
## *2.About*{:.header2-font}
&emsp;&emsp;在此之前我们需要知道一些背景知识

1.Handler

&emsp;&emsp;Handler在Android线程通讯中起着重要的作用，所以下面我罗列了一堆的Handler。

framework层Handler	|	运行线程
--|--
AMS.mUiHandler(UiHandler)|	android.ui
AMS.mBgHandler(Handler)|	android.bg
AMS.sKillHandler(KillHandler)|ActivityManagerService：kill
AMS.mHandler(MainHandler)|	ActivityManagerService
ASS.mHandler(ActivityStackSupervisorHandler)|	ActivityManagerService
AS.mHandler(ActivityStackHandler) |	ActivityManagerService
BroadcastQueue.mHandler(BroadcastHandler)	|ActivityManagerService
ActiveServices.mServiceMap(ServiceMap)|	ActivityManagerService
{:.inner-borders}

- AMS：ActivityManagerService
- ASS：ActivityStackSupervisor
- AS：ActivityStack

Application层Handler	|	运行线程
--|--
AT.mH(H)|main (UI线程)
{:.inner-borders}


2.ApplicationThread
&emsp;&emsp;ApplicationThread(IApplicationThread.Stub)为ActivityThread接收来自于服务端的响应，四大组件就是通过ApplicationThread接收了服务端的消息，从而实现了其调度。
## *3.Introduction*{:.header2-font}

### *Activity*{:.header3-font}

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-activity.png)

启动流程：
1.调用者进程通过AMS这个Framework端Binder将启动另一个Activity的信息传给SystemServer进程。
2.ActivityStarter处理了这些intent和flag等信息之后，然后交给ActivityStackSupervisior/ActivityStack去处理被调用进程的Activity进栈。如果被调用者进程存在，就会使用ApplicationThread这个Application端Binder通知已存在的被调用者进程启动Activity。如果被调用者进程不存在，就会使用Socket通知Zygote进程fork出一个进程，用来承载即将启动的Activity。
3.在新的进程里面会创建ActivityThread对象，完成开启主线程loop、ApplicationThread依附在AMS、初始化Context、Application等工作，并且通过Classload加载Activity，创建Activity对象，完成Activity生命周期的调用。

&emsp;&emsp;接下来我们细致讲解一下Application层和Framework层各个角色。

先来一张图熟悉一下Framework层的启动流程，认识一下几个重要的角色

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-activity-2.png){:.white-bg-image}

ActivityStarter：决定了intent和flag如何打开Activity和关联task、stack

ActivityStack：管理者Activity

ActivityStack管理Activity生命周期相关的几个方法。

- startActivityLocked()
- resumeTopActivityLocked()
- completeResumeLocked()
- startPausingLocked()
- completePauseLocked()
- stopActivityLocked()
- activityPausedLocked()
- finishActivityLocked()
- activityDestroyedLocked()

ActivityStackSupervisor：由于多屏功能的出现，就需要ActivityStackSupervisor这么一个类来管理ActivityStack。

下面就是管理Activity的关系图了。


![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-activity-4.png){:.white-bg-image}


&emsp;&emsp;在应用层，Activity的生命周期如下：

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-activity-3.png)

我们可以看到，在performResume方法也就是Activity的resume阶段之后才会将View通过addView呈现在屏幕上。所以唯有handleResumeActivity执行完，View才是可见的。也就是Activity#onResum的方法中，View并不是可见的，而应该是Resumed才可见。

### *Service*{:.header3-font}

Service的启动流程

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-service-start1.png)

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-service-start2.png){:.white-bg-image}

启动流程：
1.调用者进程通过AMS这个Framework端Binder将启动另一个Service的信息传给SystemServer进程。
2.ActiveService会处理即将启动的Service的信息。如果被调用者进程存在，就会使用ApplicationThread这个Application端Binder通知已存在的被调用者进程启动Service。如果被调用者进程不存在，就会使用Socket通知Zygote进程fork出一个进程，用来承载即将启动的Service。
3.在新的进程里面会创建ActivityThread对象，完成开启主线程loop、ApplicationThread依附在AMS、初始化Context、Application等工作，并且通过Classload加载Service，创建Service对象，完成Service生命周期的调用。


Service的绑定流程

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-service-bind1.png)

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-service-bind2.png){:.white-bg-image}

启动流程：
1.调用者进程通过AMS这个Framework端Binder将绑定另一个Service的信息传给SystemServer进程。
2.ActiveService会处理即将启动的Service的信息。如果被调用者进程存在，就会使用ApplicationThread这个Application端Binder通知已存在的被调用者进程启动Service。如果被调用者进程不存在，就会使用Socket通知Zygote进程fork出一个进程，用来承载即将启动的Service。
3.在新的进程里面会创建ActivityThread对象，完成开启主线程loop、ApplicationThread依附在AMS、初始化Context、Application等工作，并且通过Classload加载Service，创建Service对象，紧接着通过AMS将正在绑定的Service对客户端提供的Binder接口传给Application端的InnerConnection这个Binder，InnerConnection会让ServiceDispatcher这个派发人去分发Binder，从而实现了绑定的工作。

### *BroadcastReceiver*{:.header3-font}

![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-broadcastreceiver-1.png)

广播的动态注册是在AMS中使用Map数据结构将InnerReceiver作为key，ReceiverList（DeathRecipient子类）作为value保存起来


发送有序广播
![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-broadcastreceiver-2.png){:.white-bg-image}


启动流程：
1.调用者进程通过AMS这个Framework端Binder将广播的信息传给SystemServer进程。
2.BroadcastQueue通过内部类BroadcastHandler向已经注册广播的应用发送消息，要么通过for循环发送普通广播，要么通过方法递归发送有序广播。如果被调用者进程存在，就会使用ApplicationThread这个Application端Binder通知已存在的被调用者进程接受广播。如果被调用者进程不存在，就会使用Socket通知Zygote进程fork出一个进程，用来承载即将接受广播的Receiver。
3.在新的进程里面会创建ActivityThread对象，完成开启主线程loop、ApplicationThread依附在AMS、初始化Context、Application等工作，并且通过Classload加载BroadcastReceiver，创建BroadcastReceiver对象，完成BroadcastReceiver生命周期的调用。


### *ContentProvider*{:.header3-font}
![]({{site.asseturl}}/2018-03-15/2018-03-15-launch-contentprovider.png)


<!-- 启动流程：
1.调用者进程通过AMS这个Framework端Binder将广播的信息传给SystemServer进程。
2.BroadcastQueue通过内部类BroadcastHandler向已经注册广播的应用发送消息，要么通过for循环发送普通广播，要么通过方法递归发送有序广播。如果被调用者进程存在，就会使用ApplicationThread这个Application端Binder通知已存在的被调用者进程接受广播。如果被调用者进程不存在，就会使用Socket通知Zygote进程fork出一个进程，用来承载即将接受广播的Receiver。
3.在新的进程里面会创建ActivityThread对象，完成开启主线程loop、ApplicationThread依附在AMS、初始化Context、Application等工作，并且通过Classload加载BroadcastReceiver，创建BroadcastReceiver对象，完成BroadcastReceiver生命周期的调用。 -->

<!-- ## *4.Reference*{:.header2-font} -->

