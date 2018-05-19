---
layout: post
title: Location系统 --- 入门
description: 基本API使用
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
&emsp;&emsp;我总是在思考一个问题，如果一件事情你重来没有做过，那么要如何才能入门并且熟练上手 ？ 我认为就是把API看几遍，把相关的资料看几遍。然后再去实践，不懂在回头查看之前的资料。那么现在就让我们先入门吧

## *2.About*{:.header2-font}
&emsp;&emsp;这一篇主要讲的是API的基本使用，以及一些定位的概念，不会涉及太深的实现原理。由于现如今定位库有很多，比如google、百度、高德、腾讯，已经拿到许可证的滴滴也在做自己的定位系统。然而Android提供的定位框架却更加值得我们去阅读学习，毕竟是开源项目。所以这里的API都是Android API，而不是google在Android开发者文档推荐自己的google API。

## *3.Introduction*{:.header2-font}
&emsp;&emsp;要想使用定位，就必须通过`getSystemService(Context.LOCATION_SERVICE)`获得LocationManager对象，通过LocationManager对象可以做下面三件事

- 通过确定使用哪个LocationProvider去获取定位数据
- 注册来自LocationProvider的周期性更新数据的监听
- 注册用户进入指定的区域然后发送PendingIntent的监听

看完上面三件事，其实我们可以猜出，定位数据都是通过注册监听器，然后让底层上报数据，而这些数据绝大部分都实现了Android推荐的序列化方式Parcelable。

&emsp;&emsp;所以让我们来看看底层都会给我们提供哪些数据。

### *阅读API*{:.header3-font}
&emsp;&emsp;
![]({{site.asseturl}}/2018-01-25/2018-01-25-location-system-api-overview.png)

&emsp;&emsp;我们可以将其划分层以下几类

位置：

    Location：经纬度、时间戳、海拔、方位（bearing）等
    Geocoder：用于进行经纬度和地址两者互相转换的工具
    Address：地址



卫星：

    GnssClock：获得时钟的偏差、时钟的漂移等数据
    GnssStatus：方位（azimuth）、 信道的载波频率(carrier frequency of the signal tracked)、载波噪音密度（carrier-to-noise density）、（elevation of the satellite）
    GnssMeasurement：通过该类可以获取两种类型的数据raw information 和 computed information。比如获得adr（accumulated delta range），getAccumulatedDeltaRangeMeters()和getAccumulatedDeltaRangeUncertaintyMeters()
    GnssNavigationMessage：获取gps 导航 message

回调接口：

    GnssMeasurementsEvent.Callback：测绘的回调信息
    GnssNavigationMessage.Callback：导航的回调信息
    GnssStatus.Callback：卫星的状态回调。

### *Location 策略*{:.header3-font}
&emsp;&emsp;
![]({{site.asseturl}}/2018-01-25/2018-01-25-location-system-location-strategies.png)

&emsp;&emsp;上面是Android文档提供的最佳性能模型的timeline。那么如何做到最佳性能 ？

- 选择合适的Provider
- 及时关闭请求更新
- 获取更好的定位信息

&emsp;&emsp;1.选择合适的Provider：这个可以根据具体的情景来选择，通过Criteria可以实现选择。
```java
        Criteria criteria = new Criteria();
        criteria.setAccuracy(Criteria.ACCURACY_COARSE);
        criteria.setAltitudeRequired(true);
        criteria.setBearingAccuracy(Criteria.ACCURACY_HIGH);
        criteria.setPowerRequirement(Criteria.POWER_HIGH);
```
&emsp;&emsp;2.及时关闭请求更新：由于定位获取数据是个比较耗费电量的操作，所以不使用定位时要及时关闭。通过`removeUpdates`方法可以及时的关闭请求更新。

&emsp;&emsp;3.获取更好的定位信息：通过getLastKnownLocation获取上次缓存的定位信息，再通过requestLocationUpdates获取最新定位信息，比较两者获取最好的信息。

这边Android文档给了个挑选较好定位信息的例子。
```java
private static final int TWO_MINUTES = 1000 * 60 * 2;

/** Determines whether one Location reading is better than the current Location fix
  * @param location  The new Location that you want to evaluate
  * @param currentBestLocation  The current Location fix, to which you want to compare the new one
  */
protected boolean isBetterLocation(Location location, Location currentBestLocation) {
    if (currentBestLocation == null) {
        // A new location is always better than no location
        return true;
    }

    // Check whether the new location fix is newer or older
    long timeDelta = location.getTime() - currentBestLocation.getTime();
    boolean isSignificantlyNewer = timeDelta > TWO_MINUTES;
    boolean isSignificantlyOlder = timeDelta < -TWO_MINUTES;
    boolean isNewer = timeDelta > 0;

    // If it's been more than two minutes since the current location, use the new location
    // because the user has likely moved
    if (isSignificantlyNewer) {
        return true;
    // If the new location is more than two minutes older, it must be worse
    } else if (isSignificantlyOlder) {
        return false;
    }

    // Check whether the new location fix is more or less accurate
    int accuracyDelta = (int) (location.getAccuracy() - currentBestLocation.getAccuracy());
    boolean isLessAccurate = accuracyDelta > 0;
    boolean isMoreAccurate = accuracyDelta < 0;
    boolean isSignificantlyLessAccurate = accuracyDelta > 200;

    // Check if the old and new location are from the same provider
    boolean isFromSameProvider = isSameProvider(location.getProvider(),
            currentBestLocation.getProvider());

    // Determine location quality using a combination of timeliness and accuracy
    if (isMoreAccurate) {
        return true;
    } else if (isNewer && !isLessAccurate) {
        return true;
    } else if (isNewer && !isSignificantlyLessAccurate && isFromSameProvider) {
        return true;
    }
    return false;
}

/** Checks whether two providers are the same */
private boolean isSameProvider(String provider1, String provider2) {
    if (provider1 == null) {
      return provider2 == null;
    }
    return provider1.equals(provider2);
}
```
看完上面的代码我们可以知道通过`时间间隔`、`精确度`来判断哪个定位数据更有用。其实有时候我们还需要考虑其他因素。


## *4.Reference*{:.header2-font}
[Location Strategies](https://developer.android.com/guide/topics/location/strategies.html)
[Raw GNSS Measurements](https://developer.android.com/guide/topics/sensors/gnss.html)
[Android地理位置服务解析](http://unclechen.github.io/2016/09/02/Android%E5%9C%B0%E7%90%86%E4%BD%8D%E7%BD%AE%E6%9C%8D%E5%8A%A1%E8%A7%A3%E6%9E%90/)