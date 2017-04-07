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

//一簇设置收包完整规则的方法，默认收到数据就认为包完整。需要根据自己的需要自定义
-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator _Nullable)packetEvaluator;
-(void)setResponseMatch:(NSString* _Nonnull)prefixString
           sufferString:(NSString* _Nonnull)sufferString
     NSDataExpectLength:(int)expectLen;

//连接设备
-(void)connectDevice:(BLEStatusBlock _Nullable)myStatusBlock;

#pragma mark - 通讯方法
//1. 只发送
//2. 发送接收(同步与异步)
//3. 异步监听数据更新
//只发送
-(BOOL)sendData:(NSData * _Nonnull)data withWC:(NSString* _Nonnull)writeUUIDString;


//发送接收(同步)
-(NSData *_Nullable)sendData:(NSData * _Nonnull)data
                      withWC:(NSString* _Nonnull)writeUUIDString
                      withNC:(NSString* _Nonnull)notifyUUIDString
                     timeout:(double)timeInterval;
//发送接收(异步)
-(void)sendData:(NSData * _Nonnull)data
         withWC:(NSString* _Nonnull)writeUUIDString
         withNC:(NSString* _Nonnull)notifyUUIDString
        timeout:(double)timeInterval
    receiveData:(receiveDataBlock _Nonnull)callback;

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
//设置要搜索的服务和特征，加快连接速度
-(void)setServiceAndCharacteristicsDictionary:(NSDictionary * _Nonnull)dict;

#pragma mark  应答设置方法
//设置是否收到数据后回给蓝牙设备应答数据，自定义应答数据和应答规则。默认不应答
-(void)setAckData:(NSData* _Nullable)data withWC:(NSString * _Nullable)writeUUIDString
 withACKEvaluator:(NeekAckEvaluator _Nullable)ackEvaluator;

@end
