//
//  Typedef.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#ifndef Typedef_h_SimpleBLEKit
#define Typedef_h_SimpleBLEKit

@class SimplePeripheral;


typedef void (^SearchBlock)(SimplePeripheral* _Nonnull peripheral);


/**
 调用connectDevice后的回调，得到是否正常通讯的标志。
 
 @param isPrepareToCommunicate YES，可以开始通讯；NO ，通讯通道未准备好，不能通讯
 */
typedef void (^BLEStatusBlock)(BOOL isPrepareToCommunicate);


/**
 发送数据后接受数据的结果回调
 @param outData 有值时表示收到的数据包
 @param error 这里有值表示超时
 */
typedef void (^receiveDataBlock)(NSData * _Nullable outData,NSError * _Nullable error);
typedef void (^updateDataBlock)(NSData * _Nullable updateData);
typedef void (^readDataBlock)(NSData * _Nullable readData);
typedef BOOL (^PacketVerifyEvaluator)(NSData * __nullable inputData);
typedef BOOL (^NeekAckEvaluator)(NSData * __nullable inputData);
typedef void (^setupAfterConnected)(void);

#endif /* Typedef_h_SimpleBLEKit */


