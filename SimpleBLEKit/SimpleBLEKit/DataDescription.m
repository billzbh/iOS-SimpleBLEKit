//
//  DataDescription.m
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "DataDescription.h"

@interface DataDescription ()

@property (strong, nonatomic) NSMutableData *inputData;
@property (nonatomic, copy, readonly) PacketEvaluator responseEvaluator;
@property (nonatomic, copy, readonly) PacketEvaluator ackEvaluator;
@end

@implementation DataDescription

- (instancetype)init
{
    self = [super init];
    if (self) {
        _inputData = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    _inputData = nil;
}

-(void)clearData
{
    _inputData = [[NSMutableData alloc] init];
}

-(NSData *)getPacketData{
    return _inputData;
}

-(void)appendData:(NSData *)data{
    [_inputData appendData:data];
}

-(void)setResponseEvaluator:(PacketEvaluator)responseEvaluator
{
    if (responseEvaluator==nil) {
        _responseEvaluator = ^BOOL(NSData *d){ return [d length] > 0; };
    }else{
        _responseEvaluator = responseEvaluator;
    }
}

-(void)setNeekAckEvaluator:(PacketEvaluator)ackEvaluator
{
    if (ackEvaluator==nil) {
        _ackEvaluator = ^BOOL(NSData *d){ return [d length] > 0; };
    }else{
        _ackEvaluator = ackEvaluator;
    }
}

-(BOOL)isValidPacket{
    return _responseEvaluator(_inputData);
}

-(BOOL)isNeedToACK{
    return _ackEvaluator(_inputData);
}

@end
