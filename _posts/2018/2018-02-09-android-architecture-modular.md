---
layout: post
title: Android架构中的组件化
description: 这一篇将会解答组件化、插件化的区别
author: 电解质
date: 2018-02-09 22:50:00
share: true
comments: true
tag: 
- Android Architecture
---
* TOC
{:toc}
## *1.Summary*{:.header2-font}
&emsp;&emsp;现如今开发Android的代码量越来越庞大，容易出现dex超过64k方法，也给构建时间带来了挑战。所以在构建时间这块Android开发者使出了浑身解数，比如抛弃gradle使用buck来优化构建。为了便于团队的开发，很多Android团队使用了组件化、插件化的方式管理项目，而对于它们的共同点就是解耦代码，拆分成逻辑清晰的块。了解它们的关系就是这篇文章的关键点。
## *2.About*{:.header2-font}

|        |构建/执行  | 打包方式|
|------------ | ------------- | -------------|       
|组件化 |      编译时 |     aar|
|插件化 |      运行时 |     apk/dex|
{:.wide}

通过上面我们可以粗糙地知道组件化与插件化的区别。

&emsp;&emsp;对于插件化，主要是通过hook framework层或者虚拟机加载dex的流程来动态加载apk或者dex从而实现业务的解耦，已经实时增加，比如动态换肤、热修复。不过对于这种行为对原来的流程有很大的破坏性，而不如像gradle这样的构建工具能够给我们提供稳定的callback来的安心。所以插件化对于Android生态算是一种恶。对于这种黑科技，我倒不是很喜欢，而组件化确实是一个福音。

&emsp;&emsp;对于组件化，这里讲的是业务组件化。通过组件化，可以将业务进行拆分，这样业务就独立了，再通过路由将各个组件串联起来。除了是业务解耦，还能让组件在调试时以apk的方式打包，这样可以调高开发效率。
## *3.Introduction*{:.header2-font}

说了这么多，还是让我们来看看代码怎么写的。结合[SimpleWeather](https://github.com/HawksJamesf/SimpleWeather)这个项目来看，这个项目是我自己的开源项目，是一个轻量级App，主要关注架构一个App需要哪些技术点，欢迎您的star/fork/pr。


### *组件化配置*{:.header3-font}

```properties
isComponentMode=true
```
&emsp;&emsp;在项目根目录的gradle.properties提供一个开关，来全局控制开启组件化模式。

settings.gradle
```groovy
if (!isComponentMode.toBoolean()) {
    include ':app'
}
```
&emsp;&emsp;如果开启组件化模式，我们需要将使用组件app从整个项目去掉。为什么要这么处理呢 ？ 看看下面的配置你就知道了。
 
```groovy
if (isComponentMode.toBoolean()) {
    apply plugin: 'com.android.application'
} else {
    apply plugin: 'com.android.library'
}

android {
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
        component {
            initWith debug
            debuggable true
        }
    }
}
```
&emsp;&emsp;如果开启组件化模式，那么为了调试方便，我们需要将组件编译层apk，而不是aar/jar库。一旦被编译成apk，那么之前引用该组件的应用都要从整个项目去掉，以免造成编译报错。既然我们已经将组将编译成apk了，那么接下来就是搭建调试组件的环境了。


#### 组件目录
----

先来看看我的项目结构图。
![]({{site.asseturl}}/2018-02-09/2018-02-09-project-overview-modular.png)

&emsp;&emsp;在src目录下，我们创建了一个component目录，用来放置调试代码，比如res资源，组件启动器，AndroidManifest文件等等。这里我们有必要来说说这个目录结构，其实我们可以在src目录下创建任意个目录用来override/add main目录下的一些资源。前提是这个任意目录结构要和main相同，gradle提供了debug/release两个目录。override/add 的规则是，新建的layout/drawable两个目录会覆盖main的layout/drawable，其余的都是add。所以我们可以把main目录看成是基础资源，而新建的component目录，提供的确实一些调试代码，当编译release时，并不会受到component目录的干扰，因为，我们接下来的代码决定了component也是一种build type。

```groovy
android {
    buildTypes {
        release {
             ...
         }
        component {
            initWith debug
            debuggable true
        }
    }
}
```
&emsp;&emsp;创建完目录，我们还需要组件的build.gradle文件添加下面的代码，才能让这个目录生效。使用initWith继承debug type，在这里debuggable其实可加可不加，因为继承了debg type的特性了。

#### 组件通讯
---- 

1. Scheme 
    使用Intent/IntentFilter中的data来实现类似于网络中URL的跳转，URI的`<scheme>://<host>:<port>/<path>`通用公式，那么这样就设计到了URI的设计，数据库的URI设计是根据数据库字段，那么组件的URI设计应该根据什么 ？这是一个值得我们思考的问题。

    ```
    tel://：　
    mailto://：
    smsto://：
    content://：
    file://：
    geo://
    ```
    现如今的第三方路由库[ARouter](https://github.com/alibaba/ARouter),就是设计了一套跳转URI。这里还有一点想要说的，URI在代码代码里面最好的表现方式是什么 ？ Retrofit已经给我们解决了这个问题。而请求/想要最好的方式是什么 ？ RxJava也给我们解决了这个问题。 其实像EventBus也可以用于组件通讯，传递的是事件，但是它的请求/响应，个人感觉比起RxJava感觉有点丑。

2. RPC
    在Android中的RPC例子就是AIDL，通过Proxy/Stub 实现了通讯，[SimpleWeather](https://github.com/HawksJamesf/SimpleWeather)这个项目也是使用了一个Proxy的来转发跳转页面逻辑。


公共库代码
```java
public abstract class BaseRouterActivity{

    public Fragment switchToFragment(String fragmentName, Bundle args) {
        Fragment f = Fragment.instantiate(this, fragmentName, args);
        FragmentTransaction transaction = getFragmentManager().beginTransaction();
        ...
        transaction.commitAllowingStateLoss();
    }

    
}
```
&emsp;&emsp;BaseRouterActivity类位于所有组件的公共库，组件通过继承BaseRouterActivity类，比如写个StarterActivity类，然后通过调用父类的switchToFragment方法，将信息通过底层公共库传给其他组件。对于BaseRouterActivity类暴露给组件的switchToFragment方法做法应该，在优化一下，应该提供一个抽象方法给子类，而不应该提供一个这么重要的方法，不过为了展示代码方便就这么处理了。

组件代码
```java
public class StarterActivity extends BaseRouterActivity {

    public static final String META_DATA_KEY_FRAGMENT_CLASS =
            "FRAGMENT_CLASS";
    @Override
    protected void onCreate(Bundle savedInstanceState) {
            switchToFragment(getMetaData());
    }

     private String getMetaData() {
        try {
            ActivityInfo ai = getPackageManager().getActivityInfo(getComponentName(),
                    PackageManager.GET_META_DATA);
            if (ai == null || ai.metaData == null) return "";
            String  fragmentClass = ai.metaData.getString(META_DATA_KEY_FRAGMENT_CLASS);
              return fragmentClass;
        } catch (PackageManager.NameNotFoundException nnfe) {
            // No recovery
            Log.d("StarterActivity", "Cannot get Metadata for: " + getComponentName().toString());
        }

        return "";
    }
```
```xml
<activity
            android:name=".StarterActivity"
            android:windowSoftInputMode="stateHidden"
            android:screenOrientation="landscape"
            android:label="@string/app_name">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>

                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <meta-data android:name="FRAGMENT_CLASS"
                       android:value="应用包名.ActionCenterFragment"/>
</activity>
```
&emsp;&emsp;通过meta-data这个配置形式，使得代码更加简单化，只要在meta-data中提供想要跳转的组件就可以了。




### *组件化项目*{:.header3-font}

再看看一个组件化的案例。
![]({{site.asseturl}}/2018-02-09/2018-02-09-architecture-evolution.png)

由于初期，架构v1.x版本比较野蛮的采用了PBL分包，数据交互使用MVP，而随着代码量、业务的增长，在架构v2.x版本则采取底层按照功能模块划分，业务层通过组件化的形式将业务解耦，使其便于调试编译。这里我们确实可以看出MVP架构的价值，不像Android早期的View-Module模式，很多的保证了底层与业务层的充分解耦，如果新增业务，只要通过修改P层，从而让底层与V层做到适配，绝大多数中间人都是为了传递委一方的需求，另一方的能力。


<!-- 大部分Android项目都是使用View-Module模式开发 -->
<!-- ![](http://www.tutorialsteacher.com/Content/images/mvc/mvc-architecture.png) -->
&emsp;&emsp;
## *4.Reference*{:.header2-font}
[英语流利说 Android 架构演进](https://blog.dreamtobe.cn/2016/05/29/lls_architecture/)

[微信Android客户端架构演进之路](http://www.infoq.com/cn/articles/wechat-android-app-architecture)

[从零开始的Android新项目11 - 组件化实践（1）](http://blog.zhaiyifan.cn/2016/10/20/android-new-project-from-0-p11/)