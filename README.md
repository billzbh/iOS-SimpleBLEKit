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
3. 提供一些处理NSData的静态方法，方便新手使用
## 四. 调用流程说明


### （1）SDK中的BLEManager对象简单介绍

1. 只负责搜索设备，以及对所有搜索过(包括已连接)的设备的管理，SDK内部会移交中央设备对象给到外设对象SimplePeripheral
2. 其他一些处理NSData的方法
3. 具体的用法，你看SDK的.h就一目了然了。

-------

### （2）SDK中的SimplePeripheral简单介绍
1. 持有了CBPeripheral的对象
2. 设置好连接前的一些UUID参数后，直接开干
3. 可以通过block自己定义收包完整的规则，之后SDK根据你的收包业务逻辑实现不同的通讯协议的收发数据。

### （3）最简单流程举例:
* **在需要用到BLEManager的地方导入**

```
#import <SimpleBLEKit/BLEManager.h>
```

* **在AppDelegate.m中调用一次**

```
[BLEManager getInstance];//初始化
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

* **取得SimplePeripheral后，设置服务UUID，读写UUID**


```
[_selectedPeripheral setServiceUUID:serviceuuid Notify:notifyuuid Write:writeuuid];
```

* **开始连接**

```
[_selectedPeripheral connectDevice:^(BOOL isPrepareToCommunicate) {
    NSLog(@"设备%@",isPrepareToCommunicate?@"已连接":@"已断开");
    //通知UI层连接结果    
}];
```

* **设置收包规则**

比如你调试的通讯协议中，认为字节个数达到30，数据就收全，那你可以这么做:

```
[_selectedPeripheral setResponseEvaluator:^BOOL(NSData * inputData) {
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
[_selectedPeripheral setResponseEvaluator:^BOOL(NSData * inputData) {
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

* **发送接收数据**


经典用法:

```
[_selectedPeripheral sendData:data receiveData:^(NSData *outData, NSString *error) 
{   
    if(error){
        //发生超时错误
    }else{
        //根据你之前设置的收包规则，收到一个完整包数据。自己解析数据的含义
    }
} Timeout:-1];
```
*其他用法*:
1. 只设置data，而block为nil，timeout为-1，则表示只发送，不关心是否收到数据
2. 只设置data，block，但 timeout为-1，则表示需要收到数据，但永远不超时
3. 只设置block，但data为nil，timeout为-1，则表示一直等待Notify的数据

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
//设置是否收到数据后回给蓝牙设备应答数据。默认不应答
-(void)setAck:(BOOL)ack withData:(NSData* _Nullable)data withACKEvaluator:(PacketEvaluator _Nullable)ackEvaluator;

//暂未测试，其实还是使用setResponseEvaluator
-(void)setResponseMatch:(NSString* _Nonnull)prefixString sufferString:(NSString* _Nonnull)sufferString HighByteIndex:(int)highIndex LowByteIndex:(int)lowIndex;
-(void)setResponseMatch:(NSString* _Nonnull)prefixString sufferString:(NSString* _Nonnull)sufferString NSDataExpectLength:(int)expectLen;


```


## 六. 注意事项

* 尽量先在AppDelegate中初始化BLEManager对象。
* 听说BLE最多连接7个外设，没测试
* 导入工程直接拷贝生成的framework就可以了。 如果需要模拟器版本和真机版本合并。请看framework工程中的CreateFrameWork.txt
* 后台模式暂时不做考虑，其实是我也没有很好的解决办法🙄，要的就是简单粗暴😂。
* 感谢CCTV,感谢女儿,感谢垃圾的苹果BLE接口。怼我啊，操！🤔


## 最后欢迎大家拍砖给建议。我邮箱: bill_zbh@163.com

