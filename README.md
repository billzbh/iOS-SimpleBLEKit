# iOS-SimpleBLEKit
iOS上BLE的简单粗暴工具类。流程简单直观。适合新手使用。
## 一. demo效果

iPad demo:

![IPAD](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0010.jpg)

iphone demo：

![iphone_1](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0011.jpg) 

![iphone_2](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0012.jpg) 

![iphone_3](https://github.com/billzbh/iOS-SimpleBLEKit/blob/master/image/IMG_0013.jpg)

## 二. 写这个很SimpleBLE的背景
工作中，时不时有新的开发任务，需要接入新的蓝牙设备，而且可能蓝牙设备的报文通讯协议也是不一样的。这样以前写好的SDK中的协议就不通用了。但是对于蓝牙设备连接部分，那都是差不多的，流程是一致。

-------

再者，新手一开始编程蓝牙，一堆delegate还是有点怵。 之前也想过用一下BabyBuletooth的框架，不过一上手，发现学习入门的成本还是比较高。而对于新手，我认为SDK应该越简单越好。哪怕功能不全面。先把通讯调通才是新手的第一紧急任务。慢慢地后续有了比较多的理解，可以根据更复杂的业务去修改SDK源代码。


## 三. 优点
1. 简单，只涉及两个对象。
2. 能够同时连接多个设备，互不影响各自的通讯。
2. 可以管理所有已经连接的设备，目前只支持断开所有设备
3. 提供一些处理NSData的静态方法，方便新手使用，具体看BLEManager.h的静态方法说明
4. 非常适合【请求-回应】串口型通讯协议的开发者使用
## 四. 调用流程说明


### （1）最简单流程举例:
* **在需要用到BLEManager的地方导入**

```
#import <SimpleBLEKit/BLEManager.h>
```

* **在AppDelegate.m中调用一次**

```
[[BLEManager getInstance] setIsLogOn:YES];//初始化
```

* **在需要用到SimplePeripheral导入**

```
#import <SimpleBLEKit/SimplePeripheral.h>
```

* **执行搜索功能，上报外设对象给上层app**

```
[[BLEManager getInstance] stopScan];

[[BLEManager getInstance] startScan:^(SimplePeripheral *peripheral) {
    //可以显示搜索到的外设对象名称
    [peripheral getPeripheralName];           
} timeout:-1];//-1表示一直搜索，如果设置为10，表示10s后停止搜索
```


* **开始连接**

```
    __weak typeof(self) weakself = self;
    
    [[BLEManager getInstance] connectDevice:_selectedPeripheral callback:^(BOOL isPrepareToCommunicate) {
        
        NSLog(@"设备连接%@",isPrepareToCommunicate?@"成功":@"失败");
        
        [weakself.connectOrDisconnect setTitle:isPrepareToCommunicate?@"断开设备":@"连接设备" forState:UIControlStateNormal];
        weakself.connectOrDisconnect.tag = isPrepareToCommunicate?1:0;
    }];

```

* **设置收包规则**

比如你调试的通讯协议中，认为字节个数达到30，数据就收全，那你可以这么做:

```
[_selectedPeripheral setPacketVerifyEvaluator:^BOOL(NSData * inputData) {
    if(inputData.length>=30)
        return YES;//报告包完整
    return NO;    
}];
```

又比如你的协议可能比较复杂。规定第一个字节必须是02，第2个字节是后面有效数据的长度，最后一个字节是03

| Start | DataLen | Data | End |
| --- | --- | --- | --- |
| 0x02 | 0x?? | N个字节 = DataLen | 0x03 |

那你可以这么做:

```
[_selectedPeripheral setPacketVerifyEvaluator:^BOOL(NSData * inputData) {
    Byte *packBytes = (Byte*)[inputData bytes];
    if (packBytes[0]!=0x02) {
        return NO;
    }
    int dataLen = packBytes[1];
    int inputDataLen = (int)inputData.length;
    //包完整的数据应该是 开头1字节 + 长度1字节 + 结尾1字节 + 中间数据N字节
    if(inputDataLen < dataLen + 1 + 1 + 1)
        return NO;
    
    if(packBytes[1+dataLen]!=0x03)
        return NO;
    
    return YES;//报告包完整
}];
```

或者 如果你每次都是可以预先知道收到的数据大小，那么你可以这么做：
*比如你期望的包大小为28字节，第一个字节为0x02，最后的一个字节为0x03*

```
[_selectedPeripheral setResponseMatch:@"02" sufferString:@"03" NSDataExpectLength:28];
```



* **发送接收数据**


经典用法:

```

[_selectedPeripheral sendData:data withWC:writeuuid withNC:notifyuuid timeout:5.5 receiveData:^(NSData * _Nullable outData, NSString * _Nullable error) {
        
        if(error){
            //发生超时错误
        }else{
            //根据你之前设置的收包规则，这里会收到一个完整包数据。自己解析数据的含义
        }
    }];
    
```
*其他用法*:
1. 只发送
    `-(BOOL)sendData:(NSData * _Nonnull)data withWC:(NSString* _Nonnull)writeUUIDString;`
2. 发送接收(同步方法)
   `-(NSData *_Nullable)sendData:(NSData * _Nonnull)data
                          withWC:(NSString* _Nonnull)writeUUIDString
                          withNC:(NSString* _Nonnull)notifyUUIDString
                         timeout:(double)timeInterval;`

* **断开连接**

```
[_selectedPeripheral disconnect];
```

*以上就是完整的通讯流程* 


-------



## 五. 其他接口


```
//蓝牙名称
-(NSString* _Nonnull)getPeripheralName;
//查询是否已连接
-(BOOL)isConnected;
//是否打开日志打印，默认是NO
-(void)setIsLog:(BOOL)isLog;
//是否断开后自动重连，默认是NO
-(void)setIsAutoReconnect:(BOOL)isAutoReconnect;
//设置写数据的通知类型,默认是CBCharacteristicWriteWithoutResponse
-(void)setResponseType:(CBCharacteristicWriteType)ResponseType;
//设置是否分包发送。大于0，则按照数值分包。小于0，则不分包。默认是不分包
-(void)setMTU:(int)MTU;
//设置是否收到数据后回给蓝牙设备应答数据，自定义应答数据和应答规则。默认不应答
-(void)setAckData:(NSData* _Nullable)data withWC:(NSString * _Nullable)writeUUIDString
 withACKEvaluator:(NeekAckEvaluator _Nullable)ackEvaluator;

//自己写的简略收包完整性验证方法，设置收到的前缀和后缀，以及整个数据包的长度
-(void)setResponseMatch:(NSString* _Nonnull)prefixString
           sufferString:(NSString* _Nonnull)sufferString
     NSDataExpectLength:(int)expectLen;


```


## 六. 注意事项

* 在AppDelegate中初始化BLEManager对象。
* 听说BLE最多连接7个外设，没测试
* 导入工程直接拷贝生成的framework就可以了。 如果需要模拟器版本和真机版本合并。请看framework工程中的CreateFrameWork.txt
* 支持后台通讯，只要你的info.plist声明使用BLE后台模式
* 读取广播数据啥的，RSS啥的，我都不用，目前为止没用过，要用自己实现在外设里面。
* 对于类似蓝牙设备不断主动推数据给ios的通讯方式，而不是发请求-回数据的方式，SDK没有写，你可以在SDK里自己实现方法
* 只支持中央模式，不支持ios模拟为外设的模式。
* 此SDK不考虑多个指令并发的情况。比如我们的设备，每次都只响应一个指令，如果它还在工作中，你马上给它发下一个工作指令，它可能不会响应，除了一些取消操作指令，重置指令。所以假如你需要多个指令同时发送和接收数据，同一个notify特征应该会很难解析数据，而如果硬件支持使用不同的notify特征来接收数据的话，并且确实支持同时应答多个指令，SDK是支持同时发送接收多个指令的，互不影响。

## 七. 我自己怎么用这个SDK的。
目前公司的工程我已经使用这个SDK，三款不同的蓝牙设备工作正常。
不过我为了更方便使用它。我对
`-(void)connectDevice:(SimplePeripheral *)simplePeripheral callback:(BLEStatusBlock _Nullable)myStatusBlock`
的连接方法，通过判断蓝牙名称，然后对三款不同的设备分别设置收包规则，MTU，应答规则等，再去调用外设的连接方法。再者把通讯方法再封装一次，毕竟每次发送接收都要写uuid很是麻烦，而确定的硬件这些值都是不变。

那以后假如要增加一个蓝牙设备，我只需增加连接方法中的名称判断后的分支，以便设置新的MTU,收包规则等。


## 最后欢迎大家拍砖给建议。我邮箱: bill_zbh@163.com

