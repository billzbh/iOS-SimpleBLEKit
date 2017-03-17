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
@property (strong, nonatomic) NSString                  *ServiceUUID;
@property (strong, nonatomic) NSString                  *NotifyUUID;
@property (strong, nonatomic) NSString                  *WriteUUID;
@property (strong, nonatomic) CBCharacteristic          *readCharacteristic;
@property (strong, nonatomic) CBCharacteristic          *writeCharacteristic;
@property (copy, nonatomic)   BLEStatusBlock             MyStatusBlock;
@property (copy, nonatomic)   receiveDataBlock           callbackData;
@property (strong,nonatomic)  DataDescription            *dataDescription;
@property (assign,nonatomic)  int                       MTU;
@property (assign,nonatomic)  CBCharacteristicWriteType ResponseType;
@property (nonatomic, strong) dispatch_source_t pendingRequestTimeoutTimer;
@property (assign,nonatomic) BOOL isLog;
@property (assign,nonatomic) BOOL isAutoReconnect;
@property (assign,nonatomic) BOOL isAck;
@property (assign,nonatomic) BOOL isWorking;
@property (strong,nonatomic) NSData *AckData;
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
    _isAck = NO;
    _MTU = -1;
    _isWorking = NO;
    _ResponseType = CBCharacteristicWriteWithoutResponse;
    return self;
}

- (void)dealloc
{
    _centralManager.delegate = nil;
    _centralManager = nil;
    _dataDescription = nil;
    _ServiceUUID = nil;
    _NotifyUUID = nil;
    _WriteUUID = nil;
    _peripheral = nil;
    _readCharacteristic = nil;
    _writeCharacteristic = nil;
    _MyStatusBlock = nil;
    _callbackData = nil;
    if (_pendingRequestTimeoutTimer) {
        dispatch_source_cancel(_pendingRequestTimeoutTimer);
        _pendingRequestTimeoutTimer = nil;
    }
}

-(void)setAck:(BOOL)ack withData:(NSData*)data withACKEvaluator:(PacketEvaluator)ackEvaluator
{
    [_dataDescription setNeekAckEvaluator:ackEvaluator];
    self.isAck = ack;
    self.AckData = data;
}

-(void)setServiceUUID:(NSString *)serviceUUID Notify:(NSString*)notifyUUID Write:(NSString*)writeUUID
{
    self.ServiceUUID = serviceUUID;
    self.WriteUUID = writeUUID;
    self.NotifyUUID = notifyUUID;
}

-(void)setResponseEvaluator:(PacketEvaluator)packetEvaluator
{
    [_dataDescription setResponseEvaluator:packetEvaluator];
}

-(void)setResponseMatch:(NSString*)prefixString sufferString:(NSString*)sufferString NSDataExpectLength:(int)expectLen
{
    [_dataDescription setResponseEvaluator:^BOOL(NSData * _Nullable inputData) {
        
        if (inputData.length<expectLen) {
            return NO;
        }

        NSString *hexString = [BLEManager oneTwoData:inputData];
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
    }];
}

-(void)setResponseMatch:(NSString*)prefixString sufferString:(NSString*)sufferString HighByteIndex:(int)highIndex LowByteIndex:(int)lowIndex
{
    [_dataDescription setResponseEvaluator:^BOOL(NSData * _Nullable inputData) {
        
        if (inputData.length<highIndex+1 && inputData.length<lowIndex+1) {
            return NO;
        }
        
        Byte *inputBytes = (Byte *)[inputData bytes];
        int datalen = inputBytes[highIndex]*256 + inputBytes[lowIndex];
        if (inputData.length < datalen + (prefixString.length+1)/2) {
            return NO;
        }
        
        NSString *hexString = [BLEManager oneTwoData:inputData];
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
    }];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            if(_isLog) NSLog(@"设备已处于连接状态");
            if(_MyStatusBlock!=nil)
                _MyStatusBlock(YES);
        });
        return;
    }
    
    if(_ServiceUUID==nil){
        if(_isLog) NSLog(@"请先设置服务UUID");
        return;
    }
    
    if(_NotifyUUID==nil){
        if(_isLog) NSLog(@"请先设置读特征UUID");
        return;
    }
    
    if(_WriteUUID==nil){
        if(_isLog) NSLog(@"请先设置写特征UUID");
        return;
    }
    
    if(_dataDescription==nil){
        if(_isLog) NSLog(@"请设置收包数据描述对象DataDescription");
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
    if (self.peripheral && self.readCharacteristic) {
        [self.peripheral setNotifyValue:NO forCharacteristic:self.readCharacteristic];
        self.readCharacteristic = nil;
        self.writeCharacteristic = nil;
    }
    
    _centralManager.delegate = nil;
    if (self.peripheral) {
        [_centralManager cancelPeripheralConnection:self.peripheral];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_isLog) NSLog(@"主动断开连接");
        if(_MyStatusBlock!=nil)
            _MyStatusBlock(NO);
    });
}


//1. 发送接收等待超时，三个参数都填
//2. 只发送，不关心结果或者不需要等待收数据，只填第一个参数
//3. 一次发送数据，持续收数据包，填前两个参数，第三个参数-1 
-(void)sendData:(NSData *)data receiveData:(receiveDataBlock)callback Timeout:(NSTimeInterval)timeInterval{
    
    _callbackData = callback;
    if (_isWorking) {
        if (_callbackData)
            _callbackData(nil,@"上一个指令还未完成，无法响应新指令");
        return;
    }
    
    [_dataDescription clearData];
    isTimeout = NO;
    
    if(_isLog) NSLog(@"发送指令，等待响应中...");
    
    if (timeInterval > 0.0) {
        dispatch_queue_t timerQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, timerQueue);
        dispatch_time_t startTime = dispatch_walltime(NULL, 0);
        dispatch_source_set_timer(timer, startTime , timeInterval * NSEC_PER_SEC, 0.5 * NSEC_PER_SEC);
        __weak typeof(self) weakself = self;
        __block int first= 0;
        dispatch_source_set_event_handler(timer, ^{
            if (first==0) {
                first++;
            }else if(first==1){
                [weakself pendingRequestDidTimeout];
            }
        });
        //激活定时器会马上触发一次
        dispatch_resume(timer);
        self.pendingRequestTimeoutTimer = timer;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ //解决多线程写数据冲突的问题，使用main_queue进行排队
        
        if (_writeCharacteristic ==nil) {
            if (_callbackData)
                _callbackData(nil,@"写特征为nil，可能外设SimplePeripheral找不到此特征");
            return;
        }
        
        _isWorking = YES;
        if (_MTU <= 0 ) {//直接发送
            
            [self.peripheral writeValue:data
                      forCharacteristic:_writeCharacteristic
                                   type:_ResponseType];
            
        }else{//分包发送
        
            int length = (int)data.length;
            int offset = 0;
            int sendLength = 0;
            while (length) {
                sendLength = length;
                if (length > _MTU)
                    sendLength = _MTU;
                
                NSData *tmpData = [data subdataWithRange:NSMakeRange(offset, sendLength)];
                [self.peripheral writeValue:tmpData
                          forCharacteristic:self.writeCharacteristic
                                       type:_ResponseType];
                offset += sendLength;
                length -= sendLength;
            }
        }
    });
}

// Will only be called on timerQueue
- (void)pendingRequestDidTimeout
{
    if(_pendingRequestTimeoutTimer!=nil){
        dispatch_source_cancel(self.pendingRequestTimeoutTimer);
        self.pendingRequestTimeoutTimer = nil;
    }
    isTimeout = YES;
    _isWorking = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_callbackData)
            _callbackData(nil,@"SDK指令响应超时");
    });
}

#pragma mark  - CBCentralManagerDelegate method
//init中央设备结果回调
- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{}

//发起连接的回调结果
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{

    // Clear the data that we may already have
    if(_isLog) NSLog(@"设备连接正常，开始搜索服务...");
    
//    [self setPeripheral:peripheral];已经持有，不再需要引用
    // Make sure we get the discovery callbacks
    self.peripheral.delegate = self; //实现CBPeripheralDelegate的方法
    [self.peripheral discoverServices:[NSArray arrayWithObjects:[CBUUID UUIDWithString:_ServiceUUID],nil]];
}


//发起连接的回调结果(假设远端蓝牙关闭电源，自动连接时可能报这个错)
- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral
                  error:(NSError *)error
{
    if(_isLog) NSLog(@"设备连接异常:\n %@",error);
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_MyStatusBlock!=nil)
            _MyStatusBlock(NO);
    });
    return;
}

//（被动）断开连接的回调结果
- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                  error:(NSError *)error
{

    if(_isLog) NSLog(@"设备断开连接:\n %@",error);
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_MyStatusBlock!=nil)
            _MyStatusBlock(NO);
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
        dispatch_async(dispatch_get_main_queue(), ^{
            if(_MyStatusBlock!=nil)
                _MyStatusBlock(NO);
        });
        return;
    }
    
    
    for (CBService *service in peripheral.services) {

        if(_isLog) NSLog(@"搜索到的服务UUID: %@(%@)", service.UUID,[service.UUID UUIDString]);
        if ([service.UUID isEqual:[CBUUID UUIDWithString:_ServiceUUID]]) {
            if(_isLog) NSLog(@"服务UUID完全匹配,正在搜索读写特征");
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error) {

        if(_isLog) NSLog(@"搜索服务的读写特征时发生错误:\n %@",error);
        dispatch_async(dispatch_get_main_queue(), ^{
            if(_MyStatusBlock!=nil)
                _MyStatusBlock(NO);
        });
        return;
    }
    
    if([service.UUID isEqual:[CBUUID UUIDWithString:_ServiceUUID]]) {
        
        BOOL isNotifyReady = NO;
        BOOL isWriteReady = NO;
        for (CBCharacteristic *characteristic in service.characteristics) {
            
            if(_isLog) NSLog(@"搜索到的特征UUID: %@(%@)", characteristic.UUID,[characteristic.UUID UUIDString]);
            
            if([characteristic.UUID isEqual:[CBUUID UUIDWithString:_NotifyUUID]]) {

                if(_isLog) NSLog(@"读特征UUID完全匹配,设置监听此特征");
                self.readCharacteristic = characteristic;
                
                //此方法最终结果看 didUpdateNotificationStateForCharacteristic，一般都是成功。
                [self.peripheral setNotifyValue:YES forCharacteristic:self.readCharacteristic];
                
                isNotifyReady = YES;
                if (isWriteReady){
                    if(_isLog) NSLog(@"已经搜索到写特征,跳出查找循环");
                    break;
                }
                else{
                    if(_isLog) NSLog(@"继续查找写特征...");
                    continue;
                }
            }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:_WriteUUID]]){
                
                if(_isLog) NSLog(@"写特征UUID完全匹配");
                self.writeCharacteristic = characteristic;
                isWriteReady = YES;
                if (isNotifyReady){
                    if(_isLog) NSLog(@"已经搜索到读特征,跳出查找循环");
                    break;
                }
                else{
                    if(_isLog) NSLog(@"继续查找读特征...");
                    continue;
                }
            }
        }
        
        //跳出循环后
        if(isWriteReady && isNotifyReady){
            //通知成功前，提前做一些事情
            [self setupDeviceAfterConnected];
            if(_isLog) NSLog(@"当前连接设备为:%@",_peripheral.name);
            dispatch_async(dispatch_get_main_queue(), ^{
                if(_MyStatusBlock!=nil)
                    _MyStatusBlock(YES);
            });
        }else{
            if(_isLog) NSLog(@"未找到想要的%@特征:%@",isWriteReady==NO?@"写":@"读",isWriteReady==NO?_WriteUUID:_NotifyUUID);
            dispatch_async(dispatch_get_main_queue(), ^{
                if(_MyStatusBlock!=nil)
                    _MyStatusBlock(NO);
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
    
    if(_isLog) NSLog(@"%@特征收到数据:%@",_NotifyUUID,characteristic.value);
    if(isTimeout){
        if(_isLog) NSLog(@"指令响应已经超时，收到数据也直接返回");
        return;
    }
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:_NotifyUUID]]) {
        
        [_dataDescription appendData:characteristic.value];
        
        if (_isAck && _AckData!=nil && [_dataDescription isNeedToACK]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self.peripheral writeValue:_AckData
                          forCharacteristic:self.writeCharacteristic
                                       type:_ResponseType];
                if(_isLog) NSLog(@"我赶紧回了一个应答:%@",_AckData);
                
            });
        };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([_dataDescription isValidPacket]) {//完整包
                
                //取消定时器
                if(_pendingRequestTimeoutTimer!=nil){
                    dispatch_source_cancel(self.pendingRequestTimeoutTimer);
                    self.pendingRequestTimeoutTimer = nil;
                }
                
                if(_isLog) NSLog(@"包完整性验证OK");
                _isWorking = NO;
                if (_callbackData) {
                    _callbackData([_dataDescription getPacketData],nil);
                }
            }
        });
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        if(_isLog) NSLog(@"发送数据时出错:%@",error);
        return;
    }
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:_WriteUUID]])
        if(_isLog) NSLog(@"发送数据成功,已发送:%@",characteristic.value);
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    
    if (error) {
        if(_isLog) NSLog(@"设置监听读特征时发生错误:%@",error);
        return;
    }
    // Exit if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:_NotifyUUID]]) {
        return;
    }

    // Notification has started
    if (characteristic.isNotifying) {
        if(_isLog) NSLog(@"正在监听读特征...");
    }
    else {
        if(_isLog) NSLog(@"已取消监听读特征");
    }
}


-(void)setupDeviceAfterConnected{
    //暂时什么都不做，可以在成功连接后做一些事情
}
@end
