---
layout: post
title: Location系统 --- 启动流程
description: 讲解启动流程
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
&emsp;&emsp;不想写
## *2.About*{:.header2-font}
&emsp;&emsp;不想写
## *3.Introduction*{:.header2-font}

更新数据的开始都是源于requestLocationUpdates或者requestSingleUpdate接口，那么接下来让我们来看看下面的解析吧。
### *Application层*{:.header3-font}
&emsp;&emsp;

![]({{site.asseturl}}/2018-01-25/2018-01-25-location-system-launch-api.png)

&emsp;&emsp;提供给开发者的接口可以认为两种requestSingleUpdate和requestLocationUpdates，前者获取一次，而或者可以根据大于多少时间再更新，大于多少距离再更新。但是不论差别多大，它们的底层都是调用`requestLocationUpdates(LocationRequest request, LocationListener listener,
            Looper looper, PendingIntent intent)`实现的。

frameworks/base/location/java/android/location/LocationManager.java
```java
private void requestLocationUpdates(LocationRequest request, LocationListener listener,
            Looper looper, PendingIntent intent) {

        String packageName = mContext.getPackageName();

        // wrap the listener class
        ListenerTransport transport = wrapListener(listener, looper);

        try {
            mService.requestLocationUpdates(request, transport, intent, packageName);
       } catch (RemoteException e) {
           throw e.rethrowFromSystemServer();
       }
}
```
&emsp;&emsp;先来说说LocationManagerService，在SystemServer启动的时候调用`ServiceManager.addService(Context.LOCATION_SERVICE, location);`注册了LocationManagerService服务，当客户端调用`Context.getSystemService(Context.LOCATION_SERVICE)`时，最终LocationManager对象会通过`ServiceManager.getServiceOrThrow(Context.LOCATION_SERVICE);` 获得服务端的LocationManagerService对象mService，而接下来LocationManager和LocationManagerService这两者就可以通过binder实现了app进程和framework进程间的通信。

&emsp;&emsp;知道这些我们再来看看LocationManagerService#requestLocationUpdates方法，其注入了四个参数，如下几个。
- request: LocationRequest类对象
- transport：ILocationListener类对象
- intent：PendingIntent类对象
- packageName：使用定位功能的应用包名

1.LocationRequest类对象

&emsp;&emsp;该类是一个可持久化的Parcelable，为了通过binder到达LocationManagerService，就必须这样做，所以基本可以把它看成一个运输参数的运输车。

```java
private int mQuality = POWER_LOW;
private long mInterval = 60 * 60 * 1000;   // 60 minutes
private long mFastestInterval = (long)(mInterval / FASTEST_INTERVAL_FACTOR);  // 10 minutes
private boolean mExplicitFastestInterval = false;
private long mExpireAt = Long.MAX_VALUE;  // no expiry
private int mNumUpdates = Integer.MAX_VALUE;  // no expiry
private float mSmallestDisplacement = 0.0f;    // meters
private WorkSource mWorkSource = null;
private boolean mHideFromAppOps = false; // True if this request shouldn't be counted by AppOps

private String mProvider = LocationManager.FUSED_PROVIDER;  // for deprecated APIs that explicitly request a provider
```
&emsp;&emsp;这些参数的值都是外部调用者提供。见名只意，我们就不做细讲，等在LocationManagerService服务端用到再来将有啥用途。

2.ILocationListener类对象

&emsp;&emsp;该类是客户端用来响应服务端的回调接口。其回调接口如下：

```java
package android.location;

import android.location.Location;
import android.os.Bundle;

/**
 * {@hide}
 */
oneway interface ILocationListener
{
    void onLocationChanged(in Location location);
    void onStatusChanged(String provider, int status, in Bundle extras);
    void onProviderEnabled(String provider);
    void onProviderDisabled(String provider);
}
```
&emsp;&emsp;每一个LocationListener对象对应着一个响应服务端的ILocationListener对象，通过ILocationListener的回调方法将底层的响应传给实现了LocationListener接口的应用。这里说一下服务端的处理方式，采用锁机制同步处理来至客户端并发下发的请求。

不过有个地方值得我们关注一下。

```java
      ListenerTransport(LocationListener listener, Looper looper) {
            mListener = listener;

            if (looper == null) {
                mListenerHandler = new Handler() {
                    @Override
                    public void handleMessage(Message msg) {
                        _handleMessage(msg);
                    }
                };
            } else {
                mListenerHandler = new Handler(looper) {
                    @Override
                    public void handleMessage(Message msg) {
                        _handleMessage(msg);
                    }
                };
            }
        }
```
ILocationListener的实现类ListenerTransport通过外部调用者提供的Looper，来决定handleMessage是在主线程还是在工作线程，这也就意味着允许来自于底层的定位数据可以在在主线程刷新。

3.PendingIntent类对象
&emsp;&emsp;该类用于也是用于获取来自底层的定位数据，不过与ILocationListener不同的是，注册ILocationListener的界面会收到更新的定位数据，而PendingIntent则是将更新的定位数据传给其他的界面。还有一点需要注意的ILocationListener和PendingIntent不能同时存在，请求数据更新时，只能二选一。

### *Framework-Java层*{:.header3-font} 

frameworks/base/services/core/java/com/android/server/LocationManagerService.java
```java
@Override
public void requestLocationUpdates(LocationRequest request, ILocationListener listener,
            PendingIntent intent, String packageName) {
        ...
        // providers may use public location API's, need to clear identity
        long identity = Binder.clearCallingIdentity();
        try {
            // We don't check for MODE_IGNORED here; we will do that when we go to deliver
            // a location.
            checkLocationAccess(pid, uid, packageName, allowedResolutionLevel);

            synchronized (mLock) {
                Receiver recevier = checkListenerOrIntentLocked(listener, intent, pid, uid,
                        packageName, workSource, hideFromAppOps);
                requestLocationUpdatesLocked(sanitizedRequest, recevier, pid, uid, packageName);
            }
        } finally {
            Binder.restoreCallingIdentity(identity);
        }
}
```
&emsp;&emsp;服务端通过锁机制来处理客户端并发下发请求，所以这样就会导致请求在服务端像队列一样按照顺序被处理，而一个请求对应一个Receiver，Receiver是用来介绍底层上报的定位数据，并回调给客户端。
在锁代码块里面除了创建Receiver还有发送请求的逻辑代码，我们接着往下看。
```java
private void requestLocationUpdatesLocked(LocationRequest request, Receiver receiver,
            int pid, int uid, String packageName) {
        // Figure out the provider. Either its explicitly request (legacy use cases), or
        // use the fused provider
        if (request == null) request = DEFAULT_LOCATION_REQUEST;
        String name = request.getProvider();
    
        ...

        boolean isProviderEnabled = isAllowedByUserSettingsLocked(name, uid);
        if (isProviderEnabled) {
            applyRequirementsLocked(name);
        } else {
            // Notify the listener that updates are currently disabled
            receiver.callProviderEnabledLocked(name, false);
        }
        // Update the monitoring here just in case multiple location requests were added to the
        // same receiver (this request may be high power and the initial might not have been).
        receiver.updateMonitoring(true);
    }
```
&emsp;&emsp;requestLocationUpdatesLocked方法核心方法就是applyRequirementsLocked方法。为了下面的分析方便，我们这边还需要知道一些背景知识。

1.LocationProviderInterface接口实现类有以下三种：
- GnssLocationProvider: 定位数据来源于gps
- LocationProviderProxy：它其实是个proxy，真正的provider是NetworkLocationProvider，该类的实现需要一些服务厂商提供。国内的服务厂商有高德、百度，国外有google等
- PassiveProvider：定位数据来自于其他应用

&emsp;&emsp;这三者在启动Location服务时（SystemServer阶段），就通过在systemRunning方法中调用loadProvidersLocked方法初始化了这三个provider。

2.Receiver

&emsp;&emsp;在Receiver类里面有个成员变量mUpdateRecords，是Map类型，用来映射provider和UpdateRecord，即一种provider对应一个UpdateRecord。而对LocationManagerService的成员变量mRecordsByProvider，也是个Map类型，不过是一个provider映射一个UpdateRecord集合。
```java
 private class UpdateRecord {
        final String mProvider;
        final LocationRequest mRealRequest;  // original request from client
        LocationRequest mRequest;  // possibly throttled version of the request
        final Receiver mReceiver;
        boolean mIsForegroundUid;
        Location mLastFixBroadcast;
        long mLastStatusBroadcast;
        ...
 }
```
&emsp;&emsp;UpdateRecord用来处理一些请求的变化，比如发送请求的组件不是前台，那么就会让本来要求2分钟间隔更新数据，变成默认要求的半小时，并且将原来的请求节流改成新的请求。

&emsp;&emsp;罗里吧嗦讲完了上面的一些知识，现在终于要来讲最为重要的applyRequirementsLocked方法。
```java
 private void applyRequirementsLocked(String provider) {
        ...

        if (records != null) {
            for (UpdateRecord record : records) {
                if (isCurrentProfile(UserHandle.getUserId(record.mReceiver.mIdentity.mUid))) {
                    if (checkLocationAccess(
                            record.mReceiver.mIdentity.mPid,
                            record.mReceiver.mIdentity.mUid,
                            record.mReceiver.mIdentity.mPackageName,
                            record.mReceiver.mAllowedResolutionLevel)) {
                        LocationRequest locationRequest = record.mRealRequest;
                        long interval = locationRequest.getInterval();

                        if (!isThrottlingExemptLocked(record.mReceiver.mIdentity)) {
                            if (!record.mIsForegroundUid) {
                                interval = Math.max(interval, backgroundThrottleInterval);
                            }
                            if (interval != locationRequest.getInterval()) {
                                locationRequest = new LocationRequest(locationRequest);
                                locationRequest.setInterval(interval);
                            }
                        }

                        record.mRequest = locationRequest;
                        providerRequest.locationRequests.add(locationRequest);
                        if (interval < providerRequest.interval) {
                            providerRequest.reportLocation = true;
                            providerRequest.interval = interval;
                        }
                    }
                }
            }

            if (providerRequest.reportLocation) {
                ...
            }
        }
        ...
         p.setRequest(providerRequest, worksource);
    }

```
&emsp;&emsp;在applyRequirementsLocked方法中会先判断请求是在前台发出还是后台发出。
在Android 8.0提出来后台限制的规定，只允许后台应用每小时接收几次位置更新，前台不受影响。上面的代码就是这个限制的实现。如果想了解更多这个限制可以参考这一篇文章[Background Location Limits](https://developer.android.com/about/versions/oreo/background-location-limits.html)。然后在判断请求的interval是否小临界值，用一个临界值来限制请求的interval，如果由于频繁就会被流失掉。最后调用LocationProviderInterface#setRequest方法，之前我们已经说过LocationProviderInterface接口的实现类有三个，这里我们挑选GnssLocationProvider和LocationProviderProxy来进行分析。

#### 先来看看GnssLocationProvider

----


```java
    @Override
    public void setRequest(ProviderRequest request, WorkSource source) {
        sendMessage(SET_REQUEST, 0, new GpsRequest(request, source));
    }
```
&emsp;&emsp;sendMessage方式是对Handler发送消息的包装，GnssLocationProvider的内部类ProviderHandler是在工作线程处理来自其他线程的消息的类，这样可以避免framework主线程因执行太多任务而造成响应慢。我们来继续看看ProviderHandler到底能处理哪些消息。
```java
        @Override
        public void handleMessage(Message msg) {
            int message = msg.what;
            switch (message) {
                case ENABLE:
                    if (msg.arg1 == 1) {
                        handleEnable();
                    } else {
                        handleDisable();
                    }
                    break;
                case SET_REQUEST:
                    GpsRequest gpsRequest = (GpsRequest) msg.obj;
                    handleSetRequest(gpsRequest.request, gpsRequest.source);
                    break;
                case UPDATE_NETWORK_STATE:
                    handleUpdateNetworkState((Network) msg.obj);
                    break;
                case REQUEST_SUPL_CONNECTION:
                    handleRequestSuplConnection((InetAddress) msg.obj);
                    break;
                case RELEASE_SUPL_CONNECTION:
                    handleReleaseSuplConnection(msg.arg1);
                    break;
                case INJECT_NTP_TIME:
                    handleInjectNtpTime();
                    break;
                case DOWNLOAD_XTRA_DATA:
                    handleDownloadXtraData();
                    break;
                case INJECT_NTP_TIME_FINISHED:
                    mInjectNtpTimePending = STATE_IDLE;
                    break;
                case DOWNLOAD_XTRA_DATA_FINISHED:
                    mDownloadXtraDataPending = STATE_IDLE;
                    break;
                case UPDATE_LOCATION:
                    handleUpdateLocation((Location) msg.obj);
                    break;
                case SUBSCRIPTION_OR_SIM_CHANGED:
                    subscriptionOrSimChanged(mContext);
                    break;
                case INITIALIZE_HANDLER:
                    handleInitialize();
                    break;
            }
            if (msg.arg2 == 1) {
                // wakelock was taken for this message, release it
                mWakeLock.release();
                if (Log.isLoggable(TAG, Log.INFO)) {
                    Log.i(TAG, "WakeLock released by handleMessage(" + messageIdAsString(message)
                            + ", " + msg.arg1 + ", " + msg.obj + ")");
                }
            }
        }
```
&emsp;&emsp;ProviderHandler除了能够处理SET_REQUEST消息还能够处理下列消息
- GnssLocationProvider初始化的INITIALIZE_HANDLER消息
- SIM卡发生变化的SUBSCRIPTION_OR_SIM_CHANGED消息
- 网络可用的UPDATE_NETWORK_STATE消息
- 来自底层协议supl的RELEASE_SUPL_CONNECTION释放消息
- 请求supl连接的REQUEST_SUPL_CONNECTION连接消息
- 注入同步UTC时间的NTP的INJECT_NTP_TIME消息
- 下载同AGPS一样功能的XTRA的数据的DOWNLOAD_XTRA_DATA消息
- UPDATE_LOCATION消息

对于这么多的消息，这里我们挑INITIALIZE_HANDLER消息来讲一下。
&emsp;&emsp;在GnssLocationProvider的构造时，会发送INITIALIZE_HANDLER消息在工作线程中初始化一些东西，比如gps的一些配置属性；注册广播，注册网络是否可用的监听器
可以从config.xml读取
```xml
    <!-- Values for GPS configuration -->
    <string-array translatable="false" name="config_gpsParameters">
        <item>SUPL_HOST=supl.google.com</item>
        <item>SUPL_PORT=7275</item>
        <item>NTP_SERVER=north-america.pool.ntp.org</item>
        <item>SUPL_VER=0x20000</item>
        <item>SUPL_MODE=1</item>
    </string-array>
```
也可以从file（/etc/gps_debug.conf）读取.

```properties
#Uncommenting these urls would only enable
#the power up auto injection and force injection(test case).
#XTRA_SERVER_1=http://xtrapath1.izatcloud.net/xtra2.bin
#XTRA_SERVER_2=http://xtrapath2.izatcloud.net/xtra2.bin
#XTRA_SERVER_3=http://xtrapath3.izatcloud.net/xtra2.bin

#Version check for XTRA
#DISABLE = 0
#AUTO    = 1
#XTRA2   = 2
#XTRA3   = 3
XTRA_VERSION_CHECK=0

# Error Estimate
# _SET = 1
# _CLEAR = 0
ERR_ESTIMATE=0

#Test
NTP_SERVER=time.gpsonextra.net
#Asia
# NTP_SERVER=asia.pool.ntp.org
#Europe
# NTP_SERVER=europe.pool.ntp.org
#North America
# NTP_SERVER=north-america.pool.ntp.org

# DEBUG LEVELS: 0 - none, 1 - Error, 2 - Warning, 3 - Info
#               4 - Debug, 5 - Verbose
# If DEBUG_LEVEL is commented, Android's logging levels will be used
DEBUG_LEVEL = 3

# Intermediate position report, 1=enable, 0=disable
INTERMEDIATE_POS=0

# Below bit mask configures how GPS functionalities
# should be locked when user turns off GPS on Settings
# Set bit 0x1 if MO GPS functionalities are to be locked
# Set bit 0x2 if NI GPS functionalities are to be locked
# default - non is locked for backward compatibility
#GPS_LOCK = 0 

# supl version 1.0
SUPL_VER=0x20000

# Emergency SUPL, 1=enable, 0=disable
SUPL_ES=0

#Choose PDN for Emergency SUPL
#1 - Use emergency PDN
#0 - Use regular SUPL PDN for Emergency SUPL
USE_EMERGENCY_PDN_FOR_EMERGENCY_SUPL=0

#SUPL_MODE is a bit mask set in config.xml per carrier by default.
#If it is uncommented here, this value will overwrite the value from
#config.xml.
#MSA=0X2
#MSB=0X1
SUPL_MODE=3

# GPS Capabilities bit mask
# SCHEDULING = 0x01
# MSB = 0x02
# MSA = 0x04
# ON_DEMAND_TIME = 0x10
# GEOFENCE = 0x20
# default = ON_DEMAND_TIME | MSA | MSB | SCHEDULING | GEOFENCE
CAPABILITIES=0x37

# Accuracy threshold for intermediate positions
# less accurate positions are ignored, 0 for passing all positions
# ACCURACY_THRES=5000

################################
##### AGPS server settings #####
################################

# FOR SUPL SUPPORT, set the following
SUPL_HOST=supl.qxwz.com
SUPL_PORT=7275

# FOR C2K PDE SUPPORT, set the following
# C2K_HOST=c2k.pde.com or IP
# C2K_PORT=1234

# Bitmask of slots that are available
# for write/install to, where 1s indicate writable,
# and the default value is 0 where no slots
# are writable. For example, AGPS_CERT_WRITABLE_MASK
# of b1000001010 makes 3 slots available
# and the remaining 7 slots unwritable.
#AGPS_CERT_WRITABLE_MASK=0

####################################
#  LTE Positioning Profile Settings
####################################
# 0: Enable RRLP on LTE(Default)
# 1: Enable LPP_User_Plane on LTE
# 2: Enable LPP_Control_Plane
# 3: Enable both LPP_User_Plane and LPP_Control_Plane
LPP_PROFILE = 0

################################
# EXTRA SETTINGS
################################
# NMEA provider (1=Modem Processor, 0=Application Processor)
NMEA_PROVIDER=0
# Mark if it is a SGLTE target (1=SGLTE, 0=nonSGLTE)
SGLTE_TARGET=0

##################################################
# Select Positioning Protocol on A-GLONASS system
##################################################
# 0x1: RRC CPlane
# 0x2: RRLP UPlane
# 0x4: LLP Uplane
A_GLONASS_POS_PROTOCOL_SELECT = 0
```
&emsp;&emsp;看完这一些配置文件，又是一批概念，提供一个文章有空再来看看[Location based services with
GPS, GLONASS, Galileo and OTDOA](https://cdn.rohde-schwarz.com/pws/dl_downloads/dl_common_library/dl_news_from_rs/208/NEWS_208_english_Location_Based_Servives.pdf),主要是讲gps协议层。

&emsp;&emsp;接下来我们继续跟随SET_REQUEST的处理逻辑,最后通过 `startNavigating(singleShot);`和` stopNavigating();`控制gps开启关闭，当开启之后，hal层的新数据上报到framework-native层,framework-native层继续上报到framework-java层，而这些回调接口会在哪里被注册了 ？

&emsp;&emsp;当framework-java层中的GnssLocationProvider类初始化时，通过`static { class_init_native(); }`代码初始化framework-native层的com_android_server_location_GnssLocationProvider.cpp，初始化的时候保存了framework-java层的回调接口，以供合适的时候上报framework-native层数据给framework-native层。

frameworks/base/services/core/jni/com_android_server_location_GnssLocationProvider.cpp
```cpp
static void android_location_GnssLocationProvider_class_init_native(JNIEnv* env, jclass clazz) {
    method_reportLocation = env->GetMethodID(clazz, "reportLocation",
            "(ZLandroid/location/Location;)V");
    method_reportStatus = env->GetMethodID(clazz, "reportStatus", "(I)V");
    method_reportSvStatus = env->GetMethodID(clazz, "reportSvStatus", "()V");
    method_reportAGpsStatus = env->GetMethodID(clazz, "reportAGpsStatus", "(II[B)V");
    method_reportNmea = env->GetMethodID(clazz, "reportNmea", "(J)V");
    method_setEngineCapabilities = env->GetMethodID(clazz, "setEngineCapabilities", "(I)V");
    method_setGnssYearOfHardware = env->GetMethodID(clazz, "setGnssYearOfHardware", "(I)V");
    method_xtraDownloadRequest = env->GetMethodID(clazz, "xtraDownloadRequest", "()V");
    method_reportNiNotification = env->GetMethodID(clazz, "reportNiNotification",
            "(IIIIILjava/lang/String;Ljava/lang/String;II)V");
    method_requestRefLocation = env->GetMethodID(clazz, "requestRefLocation", "()V");
    method_requestSetID = env->GetMethodID(clazz, "requestSetID", "(I)V");
    method_requestUtcTime = env->GetMethodID(clazz, "requestUtcTime", "()V");
    method_reportGeofenceTransition = env->GetMethodID(clazz, "reportGeofenceTransition",
            "(ILandroid/location/Location;IJ)V");
    method_reportGeofenceStatus = env->GetMethodID(clazz, "reportGeofenceStatus",
            "(ILandroid/location/Location;)V");
    method_reportGeofenceAddStatus = env->GetMethodID(clazz, "reportGeofenceAddStatus",
            "(II)V");
    method_reportGeofenceRemoveStatus = env->GetMethodID(clazz, "reportGeofenceRemoveStatus",
            "(II)V");
    method_reportGeofenceResumeStatus = env->GetMethodID(clazz, "reportGeofenceResumeStatus",
            "(II)V");
    method_reportGeofencePauseStatus = env->GetMethodID(clazz, "reportGeofencePauseStatus",
            "(II)V");
    method_reportMeasurementData = env->GetMethodID(
            clazz,
            "reportMeasurementData",
            "(Landroid/location/GnssMeasurementsEvent;)V");
    method_reportNavigationMessages = env->GetMethodID(
            clazz,
            "reportNavigationMessage",
            "(Landroid/location/GnssNavigationMessage;)V");
    method_reportLocationBatch = env->GetMethodID(
            clazz,
            "reportLocationBatch",
            "([Landroid/location/Location;)V");
   ...
}

```

有21个回调接口，那么我们需要关注的是这21个回调接口的回调顺序也就是我们常说的生命周期。

#### 再来看看LocationProviderProxy

---

```java
    @Override
    public void setRequest(ProviderRequest request, WorkSource source) {
        synchronized (mLock) {
            mRequest = request;
            mWorksource = source;
        }
        ILocationProvider service = getService();
        if (service == null) return;

        try {
            service.setRequest(request, source);
        } catch (RemoteException e) {
            Log.w(TAG, e);
        } catch (Exception e) {
            // never let remote service crash system server
            Log.e(TAG, "Exception from " + mServiceWatcher.getBestPackageName(), e);
        }
    }
```

在调用setRequest之前，我们需要知道LocationProviderProxy和网络端的连接有个很重要的任务mNewServiceWork。当客户端和网络端连接成功会通过LocationWorkerHandler（用来处理工作线程的任务）执行任务。

```java
private Runnable mNewServiceWork = new Runnable() {
        @Override
        public void run() {
            if (D) Log.d(TAG, "applying state to connected service");

            boolean enabled;
            ProviderProperties properties = null;
            ProviderRequest request;
            WorkSource source;
            ILocationProvider service;
            synchronized (mLock) {
                enabled = mEnabled;
                request = mRequest;
                source = mWorksource;
                service = getService();
            }

            if (service == null) return;

            try {
                // load properties from provider
                properties = service.getProperties();
                if (properties == null) {
                    Log.e(TAG, mServiceWatcher.getBestPackageName() +
                            " has invalid locatino provider properties");
                }

                // apply current state to new service
                if (enabled) {
                    service.enable();
                    if (request != null) {
                        service.setRequest(request, source);
                    }
                }
            } catch (RemoteException e) {
                Log.w(TAG, e);
            } catch (Exception e) {
                // never let remote service crash system server
                Log.e(TAG, "Exception from " + mServiceWatcher.getBestPackageName(), e);
            }

            synchronized (mLock) {
                mProperties = properties;
            }
        }
    };
```
讲到这里的配置属性我们顺带了解一下ILocationProvider和LocationProvider。

客户端通过LocationManager的getProvider方法获得LocationProvider对象，LocationProvider有个成员变量`ProviderProperties`是需要通过binder从服务端的getProviderProperties方法获取，所以存储provider信息的ProviderProperties才是核心。那么服务端的ProviderProperties又是怎么来的呢 ？来自于LocationProviderInterface的子类。

像gps的配置信息，是直接默认初始化，就像这样
```java
    private static final ProviderProperties PROPERTIES = new ProviderProperties(
            true, true, false, false, true, true, true,
            Criteria.POWER_HIGH, Criteria.ACCURACY_FINE);
```
可以看出gps的配置信息是
- 需要Internet网络（我们常说的互联网，数据传输采用ps）
- 需要有卫星
- 不需要cellular网络（我们常说的电话通讯网，数据传输采用cs）
- 不需要花费monetary
- 需要支持上报海拔
- 需要支持上报速度
- 需要支持上报方位
- 需要电量为POWER_HIGH级别
- 需要精度为ACCURACY_FINE级别

像network的配置信息，是来至ILocationProvider,那么ILocationProvider又是什么 ？在LocationProviderProxy初始化的时候会创建ServiceConnection，ServiceConnection为ServiceConnection接口的实现类，用来连接网络端的provider。Android团队为了给优化网络的定位数据，以及为了让网络定位的服务厂商提供服务，设计了LocationProviderBase类。该类保存了ILocationProvider接口实例化对象，用来响应客户端。

来看个源码感受一下吧。

```java
public abstract class LocationProviderBase {
    ...
        private final class Service extends ILocationProvider.Stub {
        @Override
        public void enable() {
            onEnable();
        }
        @Override
        public void disable() {
            onDisable();
        }
        @Override
        public void setRequest(ProviderRequest request, WorkSource ws) {
            onSetRequest(new ProviderRequestUnbundled(request), ws);
        }
        @Override
        public ProviderProperties getProperties() {
            return mProperties;
        }
        @Override
        public int getStatus(Bundle extras) {
            return onGetStatus(extras);
        }
        @Override
        public long getStatusUpdateTime() {
            return onGetStatusUpdateTime();
        }
        @Override
        public boolean sendExtraCommand(String command, Bundle extras) {
            return onSendExtraCommand(command, extras);
        }
        @Override
        public void dump(FileDescriptor fd, String[] args) {
            PrintWriter pw = new FastPrintWriter(new FileOutputStream(fd));
            onDump(fd, pw, args);
            pw.flush();
        }
    }
    public final void reportLocation(Location location) {
        try {
            mLocationManager.reportLocation(location, false);
        } catch (RemoteException e) {
            Log.e(TAG, "RemoteException", e);
        } catch (Exception e) {
            // never crash provider, might be running in a system process
            Log.e(TAG, "Exception", e);
        }
    }
    ...
    public abstract void onSetRequest(ProviderRequestUnbundled request, WorkSource source);
    ...
    public abstract int onGetStatus(Bundle extras);
    public abstract long onGetStatusUpdateTime();
...
}
```
&emsp;&emsp;一般网络定位服务厂商需要重写LocationProviderBase类一些方法来处理来自客户端的请求，，提供provider的配置属性等等一下东西，还需要提供一个Service类用来连接ServiceWatcher。

&emsp;&emsp;Android团队为了优化定位数据，就是利用这个接口实现了FusedLocation应用。会对来自gps和network的定位数据进行比较，以便获取更加有用的数据。

该应用源码位于framework/base/packages下面

![]({{site.asseturl}}/2018-01-25/2018-01-25-location-system-launch-fusedlocation-app.png)


&emsp;&emsp;这里我们可以大致说一下Android团队如何做的。FusedLocationProvider重写了LocationProviderBase提供的方法，并且也提供了自己的配置属性。

```java
ProviderPropertiesUnbundled PROPERTIES = ProviderPropertiesUnbundled.create(
            false, false, false, false, true, true, true, Criteria.POWER_LOW,
            Criteria.ACCURACY_FINE);
```

&emsp;&emsp;可以看出服务端FusedLocation应用能够提供的配置信息是
- 不需要Internet网络（我们常说的互联网，数据传输采用ps）
- 不需要有卫星
- 不需要cellular网络（我们常说的电话通讯网，数据传输采用cs）
- 不需要花费monetary
- 需要支持上报海拔
- 需要支持上报速度
- 需要支持上报方位
- 需要电量为POWER_LOW级别
- 需要精度为ACCURACY_FINE级别

&emsp;&emsp;然后通过主线程Handler把优化的任务交给了FusionEngine类

```java
   /**
     * Test whether one location (a) is better to use than another (b).
     */
    private static boolean isBetterThan(Location locationA, Location locationB) {
      if (locationA == null) {
        return false;
      }
      if (locationB == null) {
        return true;
      }
      // A provider is better if the reading is sufficiently newer.  Heading
      // underground can cause GPS to stop reporting fixes.  In this case it's
      // appropriate to revert to cell, even when its accuracy is less.
      if (locationA.getElapsedRealtimeNanos() > locationB.getElapsedRealtimeNanos() + SWITCH_ON_FRESHNESS_CLIFF_NS) {
        return true;
      }

      // A provider is better if it has better accuracy.  Assuming both readings
      // are fresh (and by that accurate), choose the one with the smaller
      // accuracy circle.
      if (!locationA.hasAccuracy()) {
        return false;
      }
      if (!locationB.hasAccuracy()) {
        return true;
      }
      return locationA.getAccuracy() < locationB.getAccuracy();
    }
```

这个就是优化的算法。

&emsp;&emsp;接着回到ILocationProvider的setRequest方法调用，这下我们就可以轻松的知道LocationProviderProxy通过binder将请求发送给网络端的服务，而网络端的ILocationProvider接口就是接受者。
## *4.Reference*{:.header2-font}
Android Open Source Project