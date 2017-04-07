//
//  SimplePeripheral.m
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "SimplePeripheral.h"
#import "DataDescription.h"
#import "BLEManager.h"

@interface SimplePeripheral () <CBCentralManagerDelegate, CBPeripheralDelegate> {
    BOOL isTimeout;
}

@property (strong, nonatomic) CBCentralManager          *centralManager;
@property (strong, nonatomic) CBPeripheral              *peripheral;
@property (strong, nonatomic) NSDictionary              *serviceAndCharacteristicsDictionary;
@property (strong, nonatomic) NSMutableDictionary       *Services;
@property (strong, nonatomic) NSMutableDictionary       *Characteristics;
@property (copy, nonatomic)   BLEStatusBlock             MyStatusBlock;
@property (copy, nonatomic)   PacketVerifyEvaluator      packetVerifyEvaluator;
@property (copy, nonatomic)   updateDataBlock            callbackUpdateData;
@property (strong,nonatomic)  DataDescription            *dataDescription;
@property (assign,nonatomic)  int                       MTU;
@property (assign,nonatomic)  int                       CharacteristicsCount;
@property (assign,nonatomic)  int                       ServicesCount;
@property (assign,nonatomic)  CBCharacteristicWriteType ResponseType;
@property (assign,nonatomic)  BOOL                      isLog;
@property (assign,nonatomic)  BOOL                      isAutoReconnect;
@property (assign,nonatomic)  BOOL                      isWorking;
@property (strong,nonatomic)  NSData                    *AckData;
@property (strong,nonatomic)  NSString                  *AckWriteCharacteristicUUIDString;
@property (strong,nonatomic)  NSString                  *continueNotifyUUIDString;
@end


@implementation SimplePeripheral

- (instancetype)initWithCentralManager:(CBCentralManager *)manager
{
    self = [super init];
    if (!self)
        return nil;

    //初始化各个成员变量
    _centralManager = manager;
    _dataDescription = [[DataDescription alloc] init];
    _isLog = NO;
    _isAutoReconnect =NO;
    _MTU = -1;
    _CharacteristicsCount = 0;
    _ServicesCount = 0;
    _isWorking = NO;
    _ResponseType = CBCharacteristicWriteWithoutResponse;
    _Characteristics = [[NSMutableDictionary alloc] init];
    _Services = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc
{
    _centralManager.delegate = nil;
    _centralManager = nil;
    _dataDescription = nil;
    _serviceAndCharacteristicsDictionary = nil;
    _Characteristics= nil;
    _Services = nil;
    _peripheral = nil;
    _MyStatusBlock = nil;
    _packetVerifyEvaluator = nil;
    _callbackUpdateData = nil;
    _AckWriteCharacteristicUUIDString = nil;
    _continueNotifyUUIDString = nil;
}

-(void)setAckData:(NSData* _Nullable)data withWC:(NSString * _Nullable)writeUUIDString
 withACKEvaluator:(NeekAckEvaluator _Nullable)ackEvaluator
{
    _AckWriteCharacteristicUUIDString = writeUUIDString;
    [_dataDescription setNeekAckEvaluator:ackEvaluator];
    self.AckData = data;
}

-(void)setServiceAndCharacteristicsDictionary:(NSDictionary * _Nonnull)dict;
{
    _serviceAndCharacteristicsDictionary = dict;
    [_Services removeAllObjects];
    [_Characteristics removeAllObjects];
    _CharacteristicsCount = 0;
}

-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator)packetEvaluator
{
    _packetVerifyEvaluator = packetEvaluator;
    [_dataDescription setPacketVerifyEvaluator:_packetVerifyEvaluator];
}

-(void)setResponseMatch:(NSString*)prefixString sufferString:(NSString*)sufferString NSDataExpectLength:(int)expectLen
{
    
    _packetVerifyEvaluator = ^BOOL(NSData * _Nullable inputData) {
        
        if (inputData.length<expectLen) {
            return NO;
        }
        
        NSString *hexString = [BLEManager NSData2hexString:inputData];
        NSString *regularExpressions =[NSString
                                       stringWithFormat:@"%@[A-Fa-f0-9]+%@",prefixString,sufferString];
        NSRange range = [hexString rangeOfString:regularExpressions options:NSRegularExpressionSearch];
        if (range.location != NSNotFound) {
            NSString *rangeString = [hexString substringWithRange:range];
            if(rangeString.length%2==0)
                return YES;
            else
                return NO;
        }
        return NO;
    };
    
    [_dataDescription setPacketVerifyEvaluator:_packetVerifyEvaluator];
}


-(BOOL)isConnected{
    if (_peripheral) {
        if (_peripheral.state==CBPeripheralStateDisconnected) {
            return NO;
        }else if (_peripheral.state==CBPeripheralStateConnected){
            return YES;
        }else{
            return NO;
        }
    }else{
        return NO;
    }
}

-(NSString*)getPeripheralName{
    return _peripheral.name;
}

#pragma mark  -  操作方法

-(void)connectDevice:(BLEStatusBlock)myStatusBlock{
    _MyStatusBlock = myStatusBlock;
    _centralManager.delegate = self;
    
    if ([self isConnected]) {
        __weak typeof(self) weakself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if(weakself.isLog) NSLog(@"设备已处于连接状态");
            if(weakself.MyStatusBlock!=nil)
                weakself.MyStatusBlock(YES);
        });
        return;
    }
    
    if(_serviceAndCharacteristicsDictionary!=nil){
        if([_serviceAndCharacteristicsDictionary count] <=0 ){
            if(_isLog) NSLog(@"请先设置服务UUIDs");
            return;
        }
        
        if([[[_serviceAndCharacteristicsDictionary allValues] objectAtIndex:0] count] <=0 ){
            if(_isLog) NSLog(@"请先设置特征UUIDs");
            return;
        }
    }
    
    
    if(_packetVerifyEvaluator==nil){
        if(_isLog) NSLog(@"请先设置收包完整的规则,参考:\n-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator)packetEvaluator\n-(void)setResponseMatch:(NSString*)prefixString sufferString:(NSString*)sufferString NSDataExpectLength:(int)expectLen");
        return;
    }
    
    if(_isLog) NSLog(@"开始连接设备...");
    
    if([_centralManager isScanning])
        [_centralManager stopScan];
    
    if (_peripheral==nil) {
        if(_isLog) NSLog(@"发生nil错误,可能外设SimplePeripheral并不是来自搜索得来的对象");
        return;
    }

    [self.centralManager connectPeripheral:_peripheral
                                   options:nil];
    
}

-(void)disconnect{
    
    if(![self isConnected]){
        return;
    }
    
    [self setIsAutoReconnect:NO];
    _CharacteristicsCount = 0;
    if (self.peripheral) {
        
        for (CBCharacteristic* characteristic in [_Characteristics allValues]) {
            if (characteristic.isNotifying) {
                [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
            }
        }
        [_Characteristics removeAllObjects];
    }
    
    _centralManager.delegate = nil;
    if (self.peripheral) {
        [_centralManager cancelPeripheralConnection:self.peripheral];
    }
    
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if(weakself.isLog) NSLog(@"主动断开连接");
        if(weakself.MyStatusBlock!=nil)
            weakself.MyStatusBlock(NO);
    });
}



//只发送
-(BOOL)sendData:(NSData * _Nonnull)data withWC:(NSString* _Nonnull)writeUUIDString
{
    CBCharacteristic* characteristic = [_Characteristics objectForKey:writeUUIDString];
    if (characteristic ==nil) {
        //写特征为nil，可能外设SimplePeripheral找不到此特征
        if(_isLog) NSLog(@"写特征【%@】 找不到",writeUUIDString);
        return NO;
    }
    
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{ //解决多线程写数据冲突的问题，使用main_queue进行排队
        
        if (_MTU <= 0 ) {//直接发送
            
            [weakself.peripheral writeValue:data
                      forCharacteristic:characteristic
                                   type:weakself.ResponseType];
            
        }else{//分包发送
            
            int length = (int)data.length;
            int offset = 0;
            int sendLength = 0;
            while (length) {
                sendLength = length;
                if (length > _MTU)
                    sendLength = _MTU;
                
                NSData *tmpData = [data subdataWithRange:NSMakeRange(offset, sendLength)];
                [weakself.peripheral writeValue:tmpData
                          forCharacteristic:characteristic
                                       type:weakself.ResponseType];
                offset += sendLength;
                length -= sendLength;
            }
        }
    });
    return YES;
}

/*
//这些方法还未测试过
//发送接收(同步阻塞)方法,需要在子线程运行
//为什么需要阻塞方法？
//有些时候在同一个业务逻辑你需要多次反复调用发送接受接口。但每一次都是得到上一次的结果后才继续的。
//假如用block的方式，你的代码可能嵌套了好多层block。
-(NSData *_Nullable)sendData:(NSData * _Nonnull)data
                      withWC:(NSString* _Nonnull)writeUUIDString
                      withRC:(NSString* _Nonnull)readUUIDString
                     timeout:(double)timeInterval
{
    BOOL isFinish = NO;
    [_dataDescription clearData:readUUIDString];
    if([self sendData:data withWC:writeUUIDString]==NO){
        
        if(_isLog) NSLog(@"指令发送失败");
        return nil;//指令发送失败
    }
    
    CBCharacteristic* characteristic = [_Characteristics objectForKey:readUUIDString];
    if (characteristic==nil) {
        if(_isLog) NSLog(@"读特征【%@】 找不到",readUUIDString);
        return nil;
    }
    
    if (timeInterval<=0) {
        if(_isLog) NSLog(@"超时时间未设置");
        return nil;
    }
    
    NSTimeInterval timeSeconds = [self currentTimeSeconds] + timeInterval;
    while ([self currentTimeSeconds] < timeSeconds) {
        
        
        if((characteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify){
            if(_isLog && characteristic.isNotifying) NSLog(@"读特征【%@】已经被监听",readUUIDString);
        }else if((characteristic.properties & CBCharacteristicPropertyRead) == CBCharacteristicPropertyRead){
            [self.peripheral readValueForCharacteristic:characteristic];
        }else{
            if(_isLog) NSLog(@"%@特征不具备读属性[目前属性值:%lu]",readUUIDString,(unsigned long)characteristic.properties);
        }
        
        if ([_dataDescription isValidPacket:readUUIDString]) {
            isFinish = YES;
            break;
        }
        usleep(20000);
    }
    
    if (!isFinish) {
        if(_isLog) NSLog(@"接收数据超时");
        return nil;//等待数据超时
    }
    return [_dataDescription getPacketData:readUUIDString];
}

//发送接收(异步)
-(void)sendData:(NSData * _Nonnull)data
         withWC:(NSString* _Nonnull)writeUUIDString
         withRC:(NSString* _Nonnull)readUUIDString
        timeout:(double)timeInterval
    receiveData:(receiveDataBlock _Nonnull)callback
{
    
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSData *result = [weakself sendData:data withWC:writeUUIDString withRC:readUUIDString timeout:timeInterval];
        
        
        if (result==nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil,@"指令等待数据超时");
            });
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(result,nil);
            });
        }
    });
}
 
 //不断监听数据更新
 -(BOOL)updateValue:(updateDataBlock _Nullable)callback withNC:(NSString* _Nonnull)notifyUUIDString
 {
     CBCharacteristic* characteristic = [_Characteristics objectForKey:notifyUUIDString];
     if (characteristic ==nil || !characteristic.isNotifying) {
        return NO;
     }
     [_dataDescription clearData:notifyUUIDString];
     _continueNotifyUUIDString = notifyUUIDString;
     _callbackUpdateData = callback;
     return YES;
 }
 */


//发送接收(同步)
-(NSData *_Nullable)sendData:(NSData * _Nonnull)data
                      withWC:(NSString* _Nonnull)writeUUIDString
                      withNC:(NSString* _Nonnull)notifyUUIDString
                     timeout:(double)timeInterval
{
    BOOL isFinish = NO;
    [_dataDescription clearData:notifyUUIDString];
    if([self sendData:data withWC:writeUUIDString]==NO){
        
        if(_isLog) NSLog(@"指令发送失败");
        return nil;//指令发送失败
    }
    
    if (timeInterval<=0) {
        if(_isLog) NSLog(@"超时时间未设置");
        return nil;
    }
    
    NSTimeInterval timeSeconds = [self currentTimeSeconds] + timeInterval;
    while ([self currentTimeSeconds] < timeSeconds) {
        
        if ([_dataDescription isValidPacket:notifyUUIDString]) {
            isFinish = YES;
            break;
        }
        usleep(30000);
    }
    
    if (!isFinish) {
        if(_isLog) NSLog(@"接收数据超时");
        return nil;//等待数据超时
    }
    return [_dataDescription getPacketData:notifyUUIDString];
}

//发送接收(异步)
-(void)sendData:(NSData * _Nonnull)data
         withWC:(NSString* _Nonnull)writeUUIDString
         withNC:(NSString* _Nonnull)notifyUUIDString
        timeout:(double)timeInterval
    receiveData:(receiveDataBlock _Nonnull)callback
{
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSData *result = [weakself sendData:data withWC:writeUUIDString withNC:notifyUUIDString timeout:timeInterval];
        
        
        if (result==nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(nil,@"指令等待数据超时");
            });
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(result,nil);
            });
        }
    });
}


#pragma mark  - CBCentralManagerDelegate method
//init中央设备结果回调
- (void) centralManagerDidUpdateState:(CBCentralManager *)central{}
//发起连接的回调结果
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{

    // Clear the data that we may already have
    if(_isLog) NSLog(@"设备连接正常，开始搜索服务...");
    
//    [self setPeripheral:peripheral];已经持有，不再需要引用
    // Make sure we get the discovery callbacks
    self.peripheral.delegate = self; //实现CBPeripheralDelegate的方法
    
    if(_serviceAndCharacteristicsDictionary==nil){
        [self.peripheral discoverServices:nil];
    }else{
        NSMutableArray<CBUUID *> *servicesArray = [[NSMutableArray alloc] init];
        for (NSString *key in _serviceAndCharacteristicsDictionary) {
            [servicesArray addObject:[CBUUID UUIDWithString:key]];
        }
        [self.peripheral discoverServices:servicesArray];
    }
}


//发起连接的回调结果(假设远端蓝牙关闭电源，自动连接时可能报这个错)
- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
    if(_isLog) NSLog(@"设备连接异常:\n %@",error);
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if(weakself.MyStatusBlock!=nil)
            weakself.MyStatusBlock(NO);
    });
    return;
}

//（被动）断开连接的回调结果
- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                  error:(NSError *)error
{

    if(_isLog) NSLog(@"设备断开连接:\n %@",error);
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if(weakself.MyStatusBlock!=nil)
            weakself.MyStatusBlock(NO);
    });
    
    // We're disconnected, so start scanning again
    if(_isAutoReconnect){
        
        if(_isLog) NSLog(@"准备自动重连");
        
        [self.centralManager connectPeripheral:_peripheral
                                            options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                            forKey:CBCentralManagerRestoredStatePeripheralsKey]];
    }
}



#pragma mark - CBPeripheralDelegate methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        if(_isLog) NSLog(@"搜索服务时发生错误:\n %@",error);
        //主动断开设备连接
        [self disconnect];
        return;
    }
    
    if(_serviceAndCharacteristicsDictionary==nil){
        
        for (CBService *service in peripheral.services) {
            NSString *UUIDString = [service.UUID UUIDString];
            if(_isLog) NSLog(@"!!!! 搜索到的服务UUID: %@ !!!!", UUIDString);
            
            [_Services setValue:service forKey:UUIDString];
            [peripheral discoverCharacteristics:nil forService:service];
        }
        
        
    }else{
        
        if ([peripheral.services count]!=[_serviceAndCharacteristicsDictionary count]) {
            if(_isLog) NSLog(@"搜索到的服务数量不符合预期:\n%@",[peripheral.services description]);
            //主动断开设备连接
            [self disconnect];
            return;
        }
        
        
        for (CBService *service in peripheral.services) {
            NSString *UUIDString = [service.UUID UUIDString];
            if(_isLog) NSLog(@"!!!! 搜索到的服务UUID: %@ !!!!", UUIDString);
            
            [_Services setValue:service forKey:UUIDString];
            NSArray<NSString *> *characteristicArray = [_serviceAndCharacteristicsDictionary objectForKey:UUIDString];
            NSMutableArray<CBUUID *> *characteristicCBUUIDArray = [[NSMutableArray alloc] init];
            for (NSString *key in characteristicArray) {
                [characteristicCBUUIDArray addObject:[CBUUID UUIDWithString:key]];
            }
            [peripheral discoverCharacteristics:characteristicCBUUIDArray forService:service];
            _CharacteristicsCount += [characteristicCBUUIDArray count];
        }
    }
    
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error) {

        if(_isLog) NSLog(@"搜索服务的特征时发生错误:\n %@",error);
        //主动断开设备连接
        [self disconnect];
        return;
    }
    NSString *UUIDString = [service.UUID UUIDString];
    if(_isLog) NSLog(@"└┈搜索到的服务UUID: %@", UUIDString);
    
    
    if (_serviceAndCharacteristicsDictionary==nil) {
        
        _ServicesCount++;
        for (CBCharacteristic *characteristic in service.characteristics){
            
            if(_isLog) NSLog(@" └┈特征UUID: %@",[characteristic.UUID UUIDString]);
            
            if ((characteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify && characteristic.isNotifying == NO) {
                [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
            [_Characteristics setValue:characteristic forKey:[characteristic.UUID UUIDString]];
        }
        
        if (_ServicesCount == [_Services count]) {
            //通知成功前，提前做一些事情
            [self setupDeviceAfterConnected];
            if(_isLog) NSLog(@"当前连接设备为:%@",_peripheral.name);
            __weak typeof(self) weakself = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                if(weakself.MyStatusBlock!=nil)
                    weakself.MyStatusBlock(YES);
            });
        }
        
    }else{
        
        if ([service.characteristics count]!=[[_serviceAndCharacteristicsDictionary objectForKey:UUIDString] count]) {
            if(_isLog) NSLog(@"搜索到的特征数量不符合预期:\n%@",[service.characteristics description]);
            //主动断开设备连接
            [self disconnect];
            return;
        }
        
        
        for (CBCharacteristic *characteristic in service.characteristics){
            
            if(_isLog) NSLog(@" └┈特征UUID: %@",[characteristic.UUID UUIDString]);
            
            if ((characteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify && characteristic.isNotifying == NO) {
                [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
            [_Characteristics setValue:characteristic forKey:[characteristic.UUID UUIDString]];
        }
        
        if ([_Characteristics count] == _CharacteristicsCount) {//结束搜索特征
            //通知成功前，提前做一些事情
            [self setupDeviceAfterConnected];
            if(_isLog) NSLog(@"当前连接设备为:%@",_peripheral.name);
            __weak typeof(self) weakself = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                if(weakself.MyStatusBlock!=nil)
                    weakself.MyStatusBlock(YES);
            });
        }
        
    }
    
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        if(_isLog) NSLog(@"读特征收到数据时发生错误:\n %@",error);
        return;
    }
    
    NSString *uuidString = [characteristic.UUID UUIDString];
    if(_isLog) NSLog(@"%@特征收到数据:%@",uuidString,characteristic.value);
    
    [_dataDescription appendData:characteristic.value uuid:uuidString];//这里不断收集数据。

//    if ([_continueNotifyUUIDString isEqualToString:uuidString]) {
//        if ([_dataDescription isValidPacket:uuidString]) {
//            
//            __weak typeof(self) weakself = self;
//            dispatch_async(dispatch_get_main_queue(), ^{
//                weakself.callbackUpdateData([weakself.dataDescription getPacketData:uuidString]);
//                if(weakself.isLog) NSLog(@"%@更新了一包数据:%@",uuidString,[weakself.dataDescription getPacketData:uuidString]);
//            });
//            [_dataDescription clearData:uuidString];
//        }
//    }
    if (_AckData!=nil && _AckWriteCharacteristicUUIDString!=nil && [_dataDescription isNeedToACK:uuidString]) {
        
        __weak typeof(self) weakself = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [weakself.peripheral writeValue:weakself.AckData
                      forCharacteristic:[weakself.Characteristics objectForKey:weakself.AckWriteCharacteristicUUIDString]
                                   type:weakself.ResponseType];
            if(weakself.isLog) NSLog(@"我赶紧回了一个应答:%@",weakself.AckData);
        });
    };
}


#pragma mark - 基本没什么用的方法

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        if(_isLog) NSLog(@"发送数据时出错:%@",error);
        return;
    }
    if(_isLog) NSLog(@"特征%@成功发送:%@",[characteristic.UUID UUIDString],characteristic.value);
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    
    if (error) {
        if(_isLog) NSLog(@"设置或取消监听特征时发生错误:%@",error);
        return;
    }
    // Notification has started
    if(_isLog) NSLog(@"%@%@",[characteristic.UUID UUIDString],characteristic.isNotifying?@"正在监听,等待数据":@"取消监听");
}


-(void)setupDeviceAfterConnected{
    //暂时什么都不做，可以在成功连接后做一些事情
}


-(NSTimeInterval)currentTimeSeconds
{
    return [[NSDate date] timeIntervalSince1970];
}
@end
