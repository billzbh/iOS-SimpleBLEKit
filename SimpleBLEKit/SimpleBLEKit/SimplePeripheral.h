//
//  SimplePeripheral.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "Typedef.h"

@interface SimplePeripheral : NSObject
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
//设置服务UUID，读特征UUID，写特征UUID
-(void)setServiceUUID:(NSString * _Nonnull)serviceUUID Notify:(NSString* _Nonnull)notifyUUID Write:(NSString* _Nonnull)writeUUID;
//一簇设置收包完整规则的方法
-(void)setResponseEvaluator:(PacketEvaluator _Nullable)packetEvaluator;
-(void)setResponseMatch:(NSString* _Nonnull)prefixString sufferString:(NSString* _Nonnull)sufferString HighByteIndex:(int)highIndex LowByteIndex:(int)lowIndex;
-(void)setResponseMatch:(NSString* _Nonnull)prefixString sufferString:(NSString* _Nonnull)sufferString NSDataExpectLength:(int)expectLen;

//操作方法
-(void)connectDevice:(BLEStatusBlock _Nullable)myStatusBlock;
-(void)disconnect;

// 1. 只设置data，而block为nil，timeout为-1，则表示只发送，不关心是否收到数据
// 2. 只设置data，block，但 timeout为-1，则表示需要收到数据，但永远不超时
// 3. 只设置block，但data为nil，timeout为-1，则表示一直等待Notify的数据
-(void)sendData:(NSData * _Nonnull)data
    receiveData:(receiveDataBlock _Nullable)callback
        Timeout:(NSTimeInterval)timeInterval;








#pragma mark - framework内部使用的方法
- (instancetype _Nonnull)initWithCentralManager:(CBCentralManager * _Nonnull)manager;
-(void)setPeripheral:(CBPeripheral * _Nonnull)peripheral;
@end
