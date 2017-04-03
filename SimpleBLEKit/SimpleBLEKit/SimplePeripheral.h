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

#pragma mark - 必须的操作方法

//设置要搜索的服务UUIDStrings以及其服务管辖的特征UUIDStrings
-(void)setServiceAndCharacteristicsDictionary:(NSDictionary * _Nonnull)dict;

-(void)connectDevice:(BLEStatusBlock _Nullable)myStatusBlock;

#pragma mark - 簇通讯方法
//一簇通讯方法:
//1. 只发送
//2. 发送接收(同步与异步)
//3. 异步监听数据更新

//发送
-(BOOL)sendData:(NSData * _Nonnull)data withWriteCharacteristic:(NSString* _Nonnull)writeUUIDString;

//发送接收(异步)
-(void)sendData:(NSData * _Nonnull)data
withWriteCharacteristic:(NSString* _Nonnull)writeUUIDString
withNotifyCharacteristic:(NSString* _Nonnull)notifyUUIDString
        timeout:(NSTimeInterval)timeInterval
    receiveData:(receiveDataBlock _Nonnull)callback;

//发送接收(同步阻塞)方法,需要在子线程运行
//为什么需要阻塞方法？
//些时候在同一个业务逻辑你需要多次反复调用发送接受接口。但每一次都是得到上一次的结果后才继续的。
//假如用block的方式，你的代码可能嵌套了好多层block。
-(NSData *_Nullable)sendData:(NSData * _Nonnull)data
     withWriteCharacteristic:(NSString* _Nonnull)writeUUIDString
    withNotifyCharacteristic:(NSString* _Nonnull)notifyUUIDString
                     timeout:(NSTimeInterval)timeInterval;

-(NSData *_Nullable)sendData:(NSData * _Nonnull)data
     withWriteCharacteristic:(NSString* _Nonnull)writeUUIDString
    withReadCharacteristic:(NSString* _Nonnull)readUUIDString
                     timeout:(NSTimeInterval)timeInterval;


//监听数据更新
-(void)updateValueByNotifyCharacteristic:(NSString* _Nonnull)notifyUUIDString;


#pragma mark - 常用方法
//蓝牙名称
-(NSString* _Nonnull)getPeripheralName;
//查询是否已连接
-(BOOL)isConnected;
//断开连接
-(void)disconnect;

#pragma mark - 如果不需要用到相关功能，请不要设置这些方法
//是否打开日志打印，默认是NO
-(void)setIsLog:(BOOL)isLog;
//是否断开后自动重连，默认是NO
-(void)setIsAutoReconnect:(BOOL)isAutoReconnect;
//设置写数据的通知类型,默认是CBCharacteristicWriteWithoutResponse
-(void)setResponseType:(CBCharacteristicWriteType)ResponseType;
//设置是否分包发送。大于0，则按照数值分包。小于0，则不分包。默认是不分包
-(void)setMTU:(int)MTU;

#pragma mark  有意思的设置方法
//设置是否收到数据后回给蓝牙设备应答数据。默认不应答
-(void)setAckData:(NSData* _Nullable)data withWriteCharacteristic:(NSString * _Nullable)uuidString
 withACKEvaluator:(NeekAckEvaluator _Nullable)ackEvaluator;


//一簇设置收包完整规则的方法
-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator _Nullable)packetEvaluator;
-(void)setResponseMatch:(NSString* _Nonnull)prefixString
           sufferString:(NSString* _Nonnull)sufferString
     NSDataExpectLength:(int)expectLen;

@end
