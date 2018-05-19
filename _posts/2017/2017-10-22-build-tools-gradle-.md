---
layout: post
title:  构建工具Gradle
description: 
date: 2017-10-22 22:50:00
share: true
comments: true
tag:
- Build Tools
# - AOSP(APP)
---
## *1.Summary*{:.header2-font}
&emsp;&emsp;从Android团队开始宣布放弃Eclipse转投Android Studio时，构建工具Gradle进入了Android开发者的视野。而随着热修复、插件化、编译时注解的流行，深入了解Gradle就变得很有必要了。那么什么是Gradle ？
## *2.About*{:.header2-font}
&emsp;&emsp;Gradle是一个基于Ant构建工具，用Groovy DSL描述依赖关系的jar包。我们都知道早期的Android开发使用的是Eclipse,而Eclipse的构建工具使用的是Ant，用XML描述依赖关系，而XML存在太多的弊端，不如动态语言。所以动态语言Groovy代替了XML，最后集成为Gradle。而Groovy的诞生正是由于Java在后端某些地方不足，对于配置信息处理比较差，所以Apache开发了这门语言并且开源了代码。各家公司也对其进行了大量使用，其中LinkedIn公司开源了许多的Gradle插件，有兴趣的可以下载源码看看。Gradle的使用场景也很多，单元测试，自动化集成，依赖库管理等。既然说到了Java在后端的应用，必然要说道Android端的Java，与之搭配的就是最近很火的Kotlin，Kotlin也是一门动态语言，而且Kotlin和Groovy一样也可以写build.gradle文件，它们都是基于JVM的动态语言，都可以使用DSL去描述项目依赖关系。讲到这里我不禁佩服JVM生态，除了Kotlin、Groovy，还有Scala、 Clojure等,通过这些不同的语言可以去写不同层级的代码，而最后都是字节码。

## *3.Introduction*{:.header2-font}
&emsp;&emsp;我们会介绍DSL、Gradle相关知识。

### *Groovy DSL*{:.header3-font}
&emsp;&emsp;首先Groovy语言的基本知识我们不进行探讨，网上与之相关的资料有很多。我们来讲讲它的DSL，因为Gradle提供的build.gradle配置文件就是用DSL来写的。那么什么是DSL？[维基百科](https://en.wikipedia.org/wiki/Domain-specific_language)里面描述的很清楚，但是具体到代码有哪些呢?就像Android里面的AIDL（Java DSL）、HIDL，前端的JQUERY（JavaScript DSL）。由于DSL是一种为解决某种问题的领域指定语言，而不像Java这种通用性计算机语言有语法解析器，所以Android团队写了解析AIDL的语法解析器，Gradle团队写了解析Groovy DSL的语法解析器。如果想要开发针对自己公司业务的DSL，那么可以自行到网上查找相关的学习资料。不过对于中小公司都是使用成熟的DSL框架，而不是重零开始，我们只要学会使用某个DSL框架就可以了，就比如Gradle框架,只要理解框架中插件的创建，任务的定义就可以了。

&emsp;&emsp;说了这么多不如来个代码感受一下。

```groovy
apply plugin: 'com.android.application'

android {
    compileSdkVersion 23
    buildToolsVersion "27.0.0"
    defaultConfig {
        applicationId "com.hawksjamesf.myapplication"
        minSdkVersion 14
        targetSdkVersion 26
        versionCode 1
        versionName "1.0"
        testInstrumentationRunner "android.support.test.runner.AndroidJUnitRunner"
    }
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}

dependencies {
    implementation fileTree(include: ['*.jar'], dir: 'libs')
    implementation 'com.android.support:appcompat-v7:23.0.0'
    implementation 'com.android.support.constraint:constraint-layout:1.0.2'
//    testImplementation 'junit:junit:4.12'
    androidTestImplementation 'com.android.support.test:runner:1.0.1'
    androidTestImplementation 'com.android.support.test.espresso:espresso-core:3.0.1'
}
```


&emsp;&emsp;如果你是第一次接触Gradle的话，你一定表示看不懂这门语言，但是如果把它看成配置文件，是不是就能理解了。Gradle使用了大量的闭包和lamda这样简洁的语法来表示配置信息，而且Gradle中很多地方做了省略。比如去掉分号，去掉方法括号等等，力求做到精简。
&emsp;&emsp;如果你想要配置一些简单的属性，可以通过API查看，比如添加debug的配置。
{% highlight groovy %}
buildTypes {
    debug{
        println 'haha'
    }
    release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
{%endhighlight%}

&emsp;&emsp;一般DSL形成的框架都要有足够完整的API，因为其专业性太强了，就是所谓的行话，一般人看不懂，要通过查百科才能明白。
&emsp;&emsp;如果你想要根据公司的业务添加一些代码的话，那么就需要我们写任务或者插件，而这需要我们熟悉Gradle框架和Groovy语言了。

### *Gradle框架*{:.header3-font}
&emsp;&emsp;我们都知道Gradle的生命流程要经历三个部分：初始化、配置、执行。
- 初始化阶段：settings.gradle
在初始化阶段，Gradle会为每个项目创建Project对象（每个项目项目都会有一个build.gradle），那么系统是如何知道有哪些项目的，通过settings.gradle。
- 配置阶段：build.gradle
在配置阶段，Gradle会解析已经创建Project对象的项目的build.gradle文件，Project包含多个task，这些task被串在一起，存在相互依赖的关系。
- 执行阶段：task
最后就是执行这些task了。

&emsp;&emsp;基于这个流程Android团队提供了自己的插件给Android开发者写Android项目，并且有丰富的DSL文档[Android Plugin DSL Reference](https://google.github.io/android-gradle-dsl/current/)。如果想要看看Gradle官方提供的插件可以看看这个文档[Gradle Build Language Reference](https://docs.gradle.org/current/dsl/index.html)。

&emsp;&emsp;为了验证流程，我在自己的项目[SimpleWeather](https://github.com/HawksJamesf/SimpleWeather)中添加如下log。

SimpleWeather/settings.gradle
```groovy
println("settings start")
include ':app', ':location'
println("settings end")

//include ':viewpagerindicator_library'
```

SimpleWeather/build.gradle
```groovy
// Top-level build file where you can add configuration options common to all sub-projects/modules.
println("root project start")
buildscript {
    repositories {
        jcenter()
        google()



        }
    dependencies {
        classpath 'com.android.tools.build:gradle:3.0.1'
//
        // NOTE: Do not place your application dependencies here; they belong
        // in the individual module build.gradle files
    }
}

allprojects {
    repositories {
        jcenter()
        google()
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}

ext{
    compileSdkVersion=26
    buildToolsVersion ='27.0.0'
    minSdkVersion =17
    targetSdkVersion =26
    versionCode=2
    versionName="2.0"
}

println("root project end")
```

SimpleWeather/app/build.gradle
```groovy
println("app start")
apply plugin: 'com.android.application'
android {
    compileSdkVersion rootProject.ext.compileSdkVersion
    buildToolsVersion rootProject.ext.buildToolsVersion
    defaultConfig {
        minSdkVersion rootProject.ext.minSdkVersion
        targetSdkVersion rootProject.ext.targetSdkVersion
        versionCode rootProject.ext.versionCode
        versionName rootProject.ext.versionName


        multiDexEnabled = true
        applicationId "com.hawksjamesf.simpleweather"
        testInstrumentationRunner "android.support.test.runner.AndroidJUnitRunner"
        ndk {
//             设置支持的SO库架构
            abiFilters 'x86_64'
            abiFilters 'x86'
            abiFilters 'armeabi-v7a'
            abiFilters 'arm64-v8a'
        }
    }
    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
            buildConfigField("String", "BASE_URL", '"https://weatherapi.market.xiaomi.com"')
        }
        debug {
//            buildConfigField ("String","BASE_URL",'"https://api.caiyunapp.com/"')
            buildConfigField("String", "BASE_URL", '"https://weatherapi.market.xiaomi.com"')
        }
    }
    lintOptions {
//        abortOnError false
    }

    productFlavors {

    }
}

dependencies {
    implementation fileTree(include: ['*.jar'], dir: 'libs')
    //    implementation project(':viewpagerindicator_library')
    implementation 'com.jakewharton:butterknife:8.8.1'
    annotationProcessor 'com.jakewharton:butterknife-compiler:8.8.1'
    implementation 'com.google.dagger:dagger:2.11'
    annotationProcessor 'com.google.dagger:dagger-compiler:2.11'
    implementation 'com.squareup.retrofit2:retrofit:2.3.0'
    implementation 'com.squareup.retrofit2:retrofit-converters:2.3.0'
    implementation 'com.squareup.retrofit2:converter-gson:2.3.0'
    implementation 'com.squareup.retrofit2:adapter-rxjava2:2.+'
    implementation 'com.squareup.okhttp3:okhttp:3.8.1'
    implementation 'com.squareup.okhttp3:logging-interceptor:3.4.1'
    //    implementation 'com.jakewharton.timber:timber:4.5.1'
    implementation 'com.orhanobut:logger:2.1.1'
    implementation 'com.google.code.gson:gson:2.8.2'
    implementation 'org.greenrobot:eventbus:3.0.0'
    implementation 'io.reactivex.rxjava2:rxjava:2.+'
    implementation 'com.tencent.bugly:crashreport:2.6.6.1'
    implementation 'com.tencent.bugly:nativecrashreport:3.3.1'
    // Test helpers for Room
    testImplementation 'android.arch.persistence.room:testing:1.0.0'
    // Room (use 1.1.0-alpha1 for latest alpha)
    implementation 'android.arch.persistence.room:runtime:1.0.0'
    annotationProcessor "android.arch.persistence.room:compiler:1.0.0"
    // RxJava support for Room
    implementation 'android.arch.persistence.room:rxjava2:1.+'
    //    implementation "com.android.support:multidex:1.0.1"
    //noinspection GradleCompatible
    implementation 'com.android.support:appcompat-v7:26.1.0'
    implementation 'com.android.support:design:26.1.0'
    implementation 'com.android.support:recyclerview-v7:26.1.0'
    compile project(path: ':location')
}
println("app end")

```

SimpleWeather/location/build.gradle
```groovy
println("lib location start")
apply plugin: 'com.android.library'

android {
    compileSdkVersion rootProject.ext.compileSdkVersion
    buildToolsVersion rootProject.ext.buildToolsVersion
    defaultConfig {
        minSdkVersion rootProject.ext.minSdkVersion
        targetSdkVersion rootProject.ext.targetSdkVersion
        versionCode rootProject.ext.versionCode
        versionName rootProject.ext.versionName

        testInstrumentationRunner "android.support.test.runner.AndroidJUnitRunner"

    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }

}

dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])

    implementation 'com.android.support:appcompat-v7:26.1.0'
    testImplementation 'junit:junit:4.12'
    androidTestImplementation 'com.android.support.test:runner:1.0.1'
    androidTestImplementation 'com.android.support.test.espresso:espresso-core:3.0.1'
}
println("lib location end")
```

我们可以清醒的看到初始化阶段和配置阶段。
```
[0] % ./gradlew clean
Starting a Gradle Daemon, 1 incompatible Daemon could not be reused, use --status for details
settings start
settings end

> Configure project :
root project start
root project end

> Configure project :app
app start
Configuration 'compile' in project ':app' is deprecated. Use 'implementation' instead.
app end

> Configure project :location
lib location start
lib location end
```


### *Gradle任务*{:.header3-font}

#### 配置阶段调用
----

&emsp;&emsp;在前面我们粗糙地讲了task，这里我们在细讲一下。在Android DSL中默认的任务有编译、打包、签名、安装，它们按照顺序被一一执行。而我们也可以写一些hook它们流程的任务.

下面是定义task的三种方式
```groovy
task(hello) {
        println "config hello"
}

task('hello') {
        println "config hello"
}

tasks.create(name: 'hello') {
        println "config hello"
}

```

&emsp;&emsp;在Gradle中为了使得配置文件看起来更加精简，精简版之后的代码如下
```groovy
task hello {
        println "config hello"
}

tasks.create('hello') {
        println "config hello"
}
```
&emsp;&emsp;精简版是开发者最为常用的。当我们定义了任务内容，通过`./gradle  hello`就可以执行task，但是我们都知道Gradle的流程中会先配置task在执行task，而上面的代码会在`配置阶段`就被调用。那么问题来了，如果我们想要代码在`执行阶段`被调用要怎么办呢 ？ 


#### 执行阶段调用
----

看代码。
```groovy
task hello {
     println "config hello"

    doLast {
        println "excute hello"
    }
}

hello.doLast {
        println "excute hello"
}

hello.leftShift {
        println "excute hello"
}

hello << {
        println "excute hello"
}
```
&emsp;&emsp;`<<`符号的出现就是为了精简代码，所以和leftShift、doLast一样没什么可说的。所以在执行阶段执行代码的方式也就两种。

```groovy
task hello {
     println "config hello"

    doLast {
        println "excute hello"
    }
}

hello << {
        println "excute hello"
}
```

&emsp;&emsp;对于第一种可以将配置阶段的代码和执行阶段的代码写在一个闭包里面，对于第二种只能写执行阶段的代码，其中各种利弊相比已经很清晰了。

&emsp;&emsp;除了简单的定义task，还可以进阶的定义task。

来看个代码。
```groovy
task clean(type: Delete) {
    delete rootProject.buildDir
}

task copy(type: Copy) {
   from 'resources'
   into 'target'
   include('**/*.txt', '**/*.xml', '**/*.properties')
}
```
&emsp;&emsp;Delete是Gradle提供的，我们可以让自己的task拥有其特性，比如delete那个文件/文件夹。不是很明白的话，我们可以看第二个例子。想要复制一个文件可以使用Copy，`from`表示源文件，`into` 表示目标文件，`include` 表示要复制的文件。当然了这种书写方式还有另外一种，来看个代码。
```groovy
task myCopy(type: Copy)

myCopy {
   from 'resources'
   into 'target'
   include('**/*.txt', '**/*.xml', '**/*.properties')
}
```
&emsp;&emsp;Gradle并不管给我们提供了这两个task type，还有很多具体查看[Project](https://docs.gradle.org/current/dsl/org.gradle.api.Project.html#N152D1) API，页面左侧栏。当然了我们还可以写一个类继承Copy，然后重写一些属性、方法。

#### 任务相关性
---

&emsp;&emsp;有的时候我们需要增加任务的相关性，比如一个任务的执行需要另外一个任务执行完才能执行。

用代码说话
```groovy
1.
project('projectA') {
    task taskX(dependsOn: ':projectB:taskY') {
        doLast {
            println 'taskX'
        }
    }
}

project('projectB') {
    task taskY {
        doLast {
            println 'taskY'
        }
    }
}

2.
task taskX {
    doLast {
        println 'taskX'
    }
}

task taskY {
    doLast {
        println 'taskY'
    }
}

taskX.dependsOn taskY
```
&emsp;&emsp;有两种写法，一种是写在定义时，另外一种是写在调用时。

对于第二种还有它的变种版本。
```groovy
task taskX {
    doLast {
        println 'taskX'
    }
}

taskX.dependsOn {
    tasks.findAll { task -> task.name.startsWith('lib') }
}

task lib1 {
    doLast {
        println 'lib1'
    }
}

task lib2 {
    doLast {
        println 'lib2'
    }
}

task notALib {
    doLast {
        println 'notALib'
    }
}
```

除了dependsOn，你还可以使用mustRunAfter、shouldRunAfter来进行排序。

### *Gradle插件*{:.header3-font}

#### 编写Gradle插件
---
&emsp;&emsp;Gradle插件分为两种：script plugins 和 binary plugins。script plugins通过`apply from: 'other.gradle'`来引用;而binary plugins通过`apply plugin: 'com.android.application'`引用。这里我们将会讲解第二种，在讲解第二种的过程中可能会涉及到第二种。既然我们已经知道如何使用插件，那么接下来就要知道怎么定义插件。

写插件的三种方式：

- Build script
- `buildSrc` project
- Standalone project

第一种我们的代码应该这么写
>build.gradle
{:.filename}
```groovy
class GreetingPlugin implements Plugin<Project> {
    void apply(Project project) {
        project.task('hello') {
            doLast {
                println 'Hello from the GreetingPlugin'
            }
        }
    }
}

// Apply the plugin
apply plugin: GreetingPlugin
```
如果代码量较多我们就不能写在build.gradle文件，需要像编写一个库一样来写插件。而这个时候我们就可以创建一个模块，也就是第二种。

![]({{site.asseturl}}/2017-10-22/2017-10-22-gradle-project-structure.png){:.center-image}*项目的地址[SimpleWeather](https://github.com/HawksJamesf/SimpleWeather)*

这里有几点需要注意的
- 模块的名字必须是buildSrc。
- versionplugin.properties文件名的`versionplugin`对应的就是`apply plugin: versionplugin`的versionplugin，文件中通过“implementation-class=com.hawksjamesf.plugin.VersionPlugin”表明Plugin子类的位置。
- 哦对了，该模块groovy目录下的所有的文件都是用groovy写的，当然你也可以在与groovy目录同级的位置创建java目录，来放置Java代码。

&emsp;&emsp;那么对于第三种，想必我已经不用多说了吧，就是创建一个插件项目。

&emsp;&emsp;如果你想要研究Android团队写的Gradle插件源码，可以通过这里[Build Overview](http://tools.android.com/build)获取到源码。

最最后在说一句，由于Kotlin的特性，我们可以用它来替代Groovy写Gradle脚本，这样就可以减少学习Groovy的成本，而且Kotlin自从被google扶正之后，也受到了很多开发者的喜爱，很多项目也在开始用它来做开发。不过千外不要说Java的地位又不行了，身为Java程序员又在自我恐慌，戒骄戒躁，以其浪费时间在恐慌还不如多学几门不同类型语言提升自己。

## *4.Reference*{:.header2-font}

[Groovy官网](http://www.groovy-lang.org/learn.html)
[使用 Groovy 构建 DSL](https://www.ibm.com/developerworks/cn/java/j-eaed15.html)
[DSL编程技术的介绍](https://www.jianshu.com/p/17266c5b8d1c)
[CREATING YOUR OWN DSL IN KOTLIN](https://blog.simon-wirtz.de/creating-dsl-with-kotlin-introducing-a-tlslibrary/)


[Gradle的官网](https://gradle.org/)
[Kotlin Meets Gradle](https://blog.gradle.org/kotlin-meets-gradle)
[深入理解Android之Gradle](http://blog.csdn.net/innost/article/details/48228651)
[全面理解Gradle - 定义Task](http://blog.csdn.net/singwhatiwanna/article/details/78898113)


