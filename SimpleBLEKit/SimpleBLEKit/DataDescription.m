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
@property (strong, nonatomic) NSMutableDictionary *inputDataDict;
@property (nonatomic, copy, readonly) PacketVerifyEvaluator responseEvaluator;
@property (nonatomic, copy, readonly) NeekAckEvaluator ackEvaluator;

@end

@implementation DataDescription

- (instancetype)init
{
    self = [super init];
    if (self) {
        _inputData = [[NSMutableData alloc] init];
        _inputDataDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    _inputData = nil;
    _responseEvaluator = nil;
    _ackEvaluator = nil;
    _inputDataDict = nil;
}

-(void)clearData:(NSString *)uuidString
{
    _inputData = [_inputDataDict objectForKey:uuidString];
    if (_inputData==nil) {
        _inputData = [[NSMutableData alloc] init];
        [_inputDataDict setValue:_inputData forKey:uuidString];
    }else{
        [_inputData replaceBytesInRange:NSMakeRange(0, _inputData.length) withBytes:NULL length:0];
    }
}


-(NSData *)getPacketData:(NSString *)uuidString{
    
    _inputData = [_inputDataDict objectForKey:uuidString];
    return _inputData;
}

-(void)appendData:(NSData *)data uuid:(NSString *)uuidString{
    _inputData = [_inputDataDict objectForKey:uuidString];
    [_inputData appendData:data];
}

-(void)setPacketVerifyEvaluator:(PacketVerifyEvaluator)responseEvaluator
{
    
    if (responseEvaluator==nil) {
        _responseEvaluator = ^BOOL(NSData *d){ return [d length] > 0; };
    }else{
        _responseEvaluator = responseEvaluator;
    }
}

-(void)setNeekAckEvaluator:(NeekAckEvaluator)ackEvaluator
{
    if (ackEvaluator==nil) {
        _ackEvaluator = ^BOOL(NSData *d){ return NO; };
    }else{
        _ackEvaluator = ackEvaluator;
    }
}

-(BOOL)isValidPacket:(NSString *)uuidString{
    if (_responseEvaluator==nil) {
        _responseEvaluator = ^BOOL(NSData *d){ return [d length] > 0; };
    }
    _inputData = [_inputDataDict objectForKey:uuidString];
    return _responseEvaluator(_inputData);
}

-(BOOL)isNeedToACK:(NSString *)uuidString{
    if (_ackEvaluator==nil) {
        _ackEvaluator = ^BOOL(NSData *d){ return NO; };
    }
    _inputData = [_inputDataDict objectForKey:uuidString];
    return _ackEvaluator(_inputData);
}

@end
