//
//  SimplePeripheral+SimplePeripheralPrivate.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/18.
//  Copyright © 2017年 hxsmart. All rights reserved.
//



@interface SimplePeripheral ()

@property (strong, nonatomic) CBPeripheral   *__nullable peripheral;
@property (assign,nonatomic)  BOOL                      isAutoReconnect;

#pragma mark - framework内部使用的方法
- (instancetype _Nonnull)initWithCentralManager:(CBCentralManager * _Nonnull)manager;

//连接设备
-(void)connectDevice:(BLEStatusBlock _Nullable)myStatusBlock;




- (void) centralManager:(CBCentralManager *_Nonnull)central didDisconnectPeripheral:(CBPeripheral *_Nonnull)peripheral
                  error:(NSError *_Nullable)error;

- (void)centralManager:(CBCentralManager *_Nonnull)central didConnectPeripheral:(CBPeripheral *_Nonnull)peripheral;

- (void) centralManager:(CBCentralManager *_Nonnull)central didFailToConnectPeripheral:(CBPeripheral *_Nonnull)aPeripheral
                  error:(NSError *_Nullable)error;
@end
