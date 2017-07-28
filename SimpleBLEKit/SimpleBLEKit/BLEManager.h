//
//  BLEManager.h
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SimplePeripheral.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "Typedef.h"

@interface BLEManager : NSObject
//单例对象
+ (BLEManager * _Nonnull)getInstance;

//获取SDK版本
-(NSString * _Nonnull)getSDKVersion;

//初始化并决定是否打印管理对象的log
-(void)setIsLogOn:(BOOL)isLogOn;

//设置要搜索的设备的service UUID，搜索时会把系统中符合此uuids的已经连接的设备也上报。
-(void)setServiceUUIDsForSystemConnectdDevices:(NSArray<NSString *>* _Nullable)services;

//搜索过滤蓝牙名称
-(void)startScan:(SearchBlock _Nonnull)searchBLEBlock nameFilter:(NSArray<NSString *>*_Nullable)nameFilters
         timeout:(NSTimeInterval)interval;

//停止搜索
-(void)stopScan;

//连接设备
-(void)connectDevice:(SimplePeripheral * _Nonnull)simplePeripheral callback:(BLEStatusBlock _Nullable)myStatusBlock;


//返回此BLEManager对象管理的所有已连接外设
-(NSArray<SimplePeripheral *>* _Nullable)getConnectPeripherals;
//如果外设名称不同，可以通过名称从设备池中获取到已连接的外设
-(SimplePeripheral *_Nullable)getConnectPeripheralWithPrefixName:(NSString *_Nonnull)BLE_Name;
//可以通过uuid从设备池中获取到已连接的外设
-(SimplePeripheral *_Nullable)getConnectPeripheralWithUUIDString:(NSString *_Nonnull)uuid;


//断开所有本BLEManager对象管理的连接。不会也不能断开其他非本对象管理的BLE设备
-(void)disconnectAll;
-(void)disconnectWithPrefixName:(NSString * _Nonnull)name;
-(void)disconnectWithUUIDString:(NSString * _Nonnull)uuid;


#pragma mark - NSData 静态方法，也可以写成一个NSData/NSString扩展
#pragma mark

/**
 将16进制格式的字符串转为二进制，例如 "11ABCD",内存中数据为: {0x31,0x31,0x41,0x42,0x43,0x44}实际占用6字节.
 转化后内存中数据: {0x11,0xAB,0xCD},实际占用3字节
 @param hexString hexString格式的字符串
 @return data内存原始数据
 */
+ (NSData * _Nonnull)hexString2NSData:(NSString * _Nonnull)hexString;


/**
 和twoOneData的作用相反，可以将内存中的数据，打印成16进制可见字符串

 @param sourceData 内存原始数据
 @return hexString格式字符串
 */
+ (NSString * _Nonnull)NSData2hexString:(NSData * _Nonnull)sourceData;


//将两个字节3X 3X 转换--》XX（一个字节）（例如0x31 0x3b ----》 0x1b ）有点类似压缩BCD
+(NSData * _Nonnull)twoOneWith3xString:(NSString * _Nonnull)_3xString;

//将XX（一个字节） 转换--》3x 3x （例如 0x1b ----》 0x31 0x3b 此时显示成字符为  "1;"
+(NSString * _Nonnull)oneTwo3xString:(NSData * _Nonnull)sourceData;


/**
 * 计算两组byte数组异或后的值。两组的大小要一致。
 * @param bytesData1 NSData1
 * @param bytesData2 NSData2
 * @return    异或后的NSData
 */
+(NSData * _Nonnull)BytesData:(NSData * _Nonnull)bytesData1 XOR:(NSData * _Nonnull)bytesData2;


//计算一个NSData逐个字节异或后的值
+(Byte) XOR:(NSData * _Nonnull)sourceData;
+(Byte) XOR:(Byte * _Nonnull)sourceBytes offset:(int)offset length:(int)len;

/*
 * 四个字节的byte数组转为int
 * @param src                 字节数组指针
 * @param offset              字节数组的位移
 * @param srcIsBigEnddian     输入数组是否为大端表示，如果是，此方法内部实现将会转为小端表示。
 * @return  整数数值，结果为小端表示
 */
+(int)bytes2integer:(Byte *_Nonnull)src offset:(int)offset srcIsBigEnddian:(BOOL)srcIsBigEnddian;

/*
 * 将4个字节转换为float数据
 * @param src                 字节数组指针
 * @param offset              字节数组的位移
 * @param srcIsBigEnddian     指示输入数组是否为大端表示，如果YES，此方法内部实现将会转为小端表示。
 * @return  浮点数值，结果为小端表示
 */
+(float)bytes2float:(Byte *_Nonnull)inbytes offset:(int)offset srcIsBigEnddian:(BOOL)srcIsBigEnddian;

/*
 * int转为4个字节NSData
 * @param value              整数数值
 * @param resultIsBigEndian  结果是否需要为大端表示。
 * @return  4字节的NSData
 */
+(NSData *_Nonnull)integer2data:(int)value resultIsBigEndian:(BOOL)resultIsBigEndian;


/*
 * 将float数据转为4个字节的NSData
 * @param value              整数数值
 * @param resultIsBigEndian  结果是否需要为大端表示。
 * @return  4字节的NSData
 */
+(NSData *_Nonnull)float2data:(float)value resultIsBigEndian:(BOOL)resultIsBigEndian;
@end
