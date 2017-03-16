//
//  DataDescription.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Typedef.h"

@interface DataDescription : NSObject

-(void)clearData;

-(void)appendData:(NSData* _Nonnull)data;

-(void)setResponseEvaluator:(PacketEvaluator _Nonnull)responseEvaluator;

-(void)setNeekAckEvaluator:(PacketEvaluator _Nonnull)ackEvaluator;

-(BOOL)isValidPacket;//每次调用都会调用PacketEvaluator块函数解析是否收包正确。如果正确就通知，失败继续直到超时
-(BOOL)isNeedToACK;//每次调用都会调用PacketEvaluator块函数解析是否需要回ACK

-(NSData * _Nonnull)getPacketData;

@end
