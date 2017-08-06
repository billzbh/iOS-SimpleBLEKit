//
//  DataDescription.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SimpleBLEKitTypeDef.h"

@interface DataDescription : NSObject

-(void)clearData:(NSString * _Nonnull)uuidString;

-(void)appendData:(NSData* _Nonnull)data uuid:(NSString * _Nonnull)uuidString;

-(NSData * _Nonnull)getPacketData:(NSString * _Nonnull)uuidString;


-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator _Nonnull)packetVerifyEvaluator;

-(void)setNeekAckEvaluator:(NeekAckEvaluator _Nonnull)ackEvaluator;

-(BOOL)isValidPacket:(NSString * _Nonnull)uuidString;//每次调用都会调用PacketEvaluator块函数解析是否收包正确。如果正确就通知，失败继续直到超时

-(BOOL)isNeedToACK:(NSString * _Nonnull)uuidString;//每次调用都会调用PacketEvaluator块函数解析是否需要回ACK

@end
