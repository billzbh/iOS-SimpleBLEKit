//
//  BLEManager.m
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "BLEManager.h"
#import "SimplePeripheralPrivate.h"
#import <ExternalAccessory/ExternalAccessory.h>
#import <CoreFoundation/CFByteOrder.h>

#define BLE_SDK_VERSION @"20170801_LAST_COMMIT=9a10f2f"

@interface BLEManager () <CBCentralManagerDelegate>
@property (strong, nonatomic) NSArray<NSString *>* FilterBleNameArray;
@property (strong, nonatomic) CBCentralManager  *centralManager;
@property (strong, nonatomic) NSMutableArray<CBUUID *>  *services;
@property (nonatomic,copy) SearchBlock MysearchBLEBlock;
@property (strong,nonatomic) NSMutableDictionary *Device_dict;//已连接的对象
@property (strong, nonatomic) NSMutableDictionary  *searchedDeviceUUIDArray;
@property (assign,nonatomic) BOOL isLogOn;

@end

@implementation BLEManager

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _services = [[NSMutableArray alloc] init];
    _Device_dict = [[NSMutableDictionary alloc] init];
    dispatch_queue_t _centralManagerQueue = dispatch_queue_create("com.zbh.SimpleBLEKit.centralManagerQueue", DISPATCH_QUEUE_SERIAL);
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_centralManagerQueue options:nil];
    _isLogOn = NO;
    return self;
}

- (void)dealloc
{
    _centralManager=nil;
    _MysearchBLEBlock = nil;
    [_Device_dict removeAllObjects];
    _Device_dict = nil;
    [_searchedDeviceUUIDArray removeAllObjects];
    _searchedDeviceUUIDArray = nil;
    [_services removeAllObjects];
    _services = nil;
}


+ (BLEManager *)getInstance
{
    static BLEManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[BLEManager alloc] init];
        NSLog(@"SimpleBLEKit Version: %@",BLE_SDK_VERSION);
    });
    return sharedInstance;
}

-(NSString *)getSDKVersion{
    return BLE_SDK_VERSION;
}

-(void)setServiceUUIDsForSystemConnectdDevices:(NSArray<NSString *>*)services
{
    [_services removeAllObjects];
    for (NSString *uuid in services) {
        [_services addObject:[CBUUID UUIDWithString:uuid]];
    }
}

//如果外设名称不同，可以通过这个获取到已连接的外设
-(SimplePeripheral *)getConnectPeripheralWithPrefixName:(NSString *)BLE_Name{
    NSArray *array = [_Device_dict allValues];
    for (SimplePeripheral *peripheral in array) {
        if ([peripheral isConnected] && [[peripheral getPeripheralName] hasPrefix:BLE_Name]) {
            return peripheral;
        }
    }
    return nil;
}

-(SimplePeripheral *_Nullable)getConnectPeripheralWithUUIDString:(NSString *_Nonnull)uuid{
    SimplePeripheral *peripheral = [_Device_dict objectForKey:uuid];
    return peripheral;
}

//返回本管理对象BLEManager的所有已连接对象
-(NSArray<SimplePeripheral *>*)getConnectPeripherals
{
    NSArray *array;
    NSMutableArray *connectedDevices;
    array = [_Device_dict allValues];
    if (array == nil || [array count]==0) {
        return nil;
    }
    connectedDevices = [NSMutableArray arrayWithArray:array];
    for (SimplePeripheral *peripheral in array) {
        if (![peripheral isConnected]) {
            [connectedDevices removeObject:peripheral];
        }
    }
    return connectedDevices;
}

-(void)connectDevice:(SimplePeripheral *)simplePeripheral callback:(BLEStatusBlock _Nullable)myStatusBlock
{

    
//    __weak typeof(self) weakself = self;//记得防止block循环引用
    [simplePeripheral connectDevice:^(BOOL isPrepareToCommunicate) {
        
        if (isPrepareToCommunicate) {
            //如果自己公司的SDK要兼容几种不同协议的外设
            //可以直接在这里通过不同的外设名称，区分不同的收发规则等，外部调用就不再需要设置，也不会暴露协议。
            //还可以通过不同的外设名称，将外设对象返回给更复杂功能的对象，使得它可以利用外设的通讯方法封装更多不同的方法。
        }
        myStatusBlock(isPrepareToCommunicate);
    }];
}


//合并 startSearch 和 connectDevice 方法。直接连接符合蓝牙名称的设备
-(void)scanAndConnected:(NSArray<NSString *>*)btNameArray
               callback:(searchAndConnectBlock _Nullable)multiDeviceBlock
{
    [self startScan:^(SimplePeripheral * _Nonnull peripheral) {
        if ([btNameArray containsObject:peripheral.getPeripheralName]) {
            [peripheral connectDevice:^(BOOL isPrepareToCommunicate) {
                
                if (isPrepareToCommunicate) {
                    //如果自己公司的SDK要兼容几种不同协议的外设
                    //可以直接在这里通过不同的外设名称，区分不同的收发规则等，外部调用就不再需要设置，也不会暴露协议。
                    //还可以通过不同的外设名称，将外设对象返回给更复杂功能的对象，使得它可以利用外设的通讯方法封装更多不同的方法。
                }
                multiDeviceBlock(peripheral,isPrepareToCommunicate);
            }];
        }
    } nameFilter:btNameArray timeout:2*btNameArray.count+2];
}


-(void)disconnectAll{
    
    for (NSString *key in _Device_dict) {
        SimplePeripheral *peripheral = _Device_dict[key];
        [peripheral disconnect];
    }
}

-(void)disconnectWithPrefixName:(NSString * _Nonnull)name{
    
    for (NSString *key in _Device_dict) {
        SimplePeripheral *peripheral = _Device_dict[key];
        if ([peripheral isConnected] && [[peripheral getPeripheralName] hasPrefix:name]) {
            [peripheral disconnect];
        }
    }
}

-(void)disconnectWithUUIDString:(NSString * _Nonnull)uuid;
{
    for (NSString *key in _Device_dict) {
        SimplePeripheral *peripheral = _Device_dict[key];
        NSString *uuidString = [[peripheral peripheral].identifier UUIDString];
        if ([peripheral isConnected] && [uuidString isEqualToString:uuid]){
            [peripheral disconnect];
        }
    }
}

//搜索符合过滤名称的设备
-(void)startScan:(SearchBlock)searchBLEBlock nameFilter:(NSArray<NSString *>*)nameFilters
         timeout:(NSTimeInterval)interval
{
    _FilterBleNameArray = nameFilters;
    _MysearchBLEBlock = searchBLEBlock;
    _centralManager.delegate = self;
    if (_searchedDeviceUUIDArray==nil) {
        _searchedDeviceUUIDArray = [[NSMutableDictionary alloc] init];
    }else{
        [_searchedDeviceUUIDArray removeAllObjects];
    }
    
    if(_isLogOn) NSLog(@"搜索前，上报设备池中已连接的外设...");
    //将已经连接的设备也上报
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSString *key in weakself.Device_dict) {
            
            SimplePeripheral *peripheral = weakself.Device_dict[key];
            if ([peripheral isConnected]) {
                if(_isLogOn) NSLog(@"└┈上报%@",[peripheral getPeripheralName]);
                if (weakself.MysearchBLEBlock) {
                    weakself.MysearchBLEBlock(peripheral);
                }
            }
        }
    });
    
    //上报系统中别的app已经连接的,但此对象_centralManager还未连接的蓝牙设备
    if ([_services count]>0) {
        NSArray<CBPeripheral *>* connectPeripherals = [_centralManager retrieveConnectedPeripheralsWithServices:_services];
        SimplePeripheral *tmpPeripheral;
        for (CBPeripheral *cbP in connectPeripherals) {
            if(_isLogOn) NSLog(@"└┈搜索到其他app已连接的设备:%@(上报应用层)",cbP.name);
            if(_FilterBleNameArray!=nil){
                int i = 0;
                for (NSString* name in _FilterBleNameArray) {
                    if([cbP.name containsString:name])
                        break;
                    i++;
                }
                if (i==[_FilterBleNameArray count]) {
                    continue;
                }
            }
            
            if(cbP.state==CBPeripheralStateDisconnected){
                tmpPeripheral = [[SimplePeripheral alloc] initWithCentralManager:_centralManager];
                [tmpPeripheral setPeripheral:cbP];
                [_Device_dict setValue:tmpPeripheral forKey:[cbP.identifier UUIDString]];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (weakself.MysearchBLEBlock) {
                        weakself.MysearchBLEBlock(tmpPeripheral);
                    }
                });
            }
        }
    }
    
    if (interval>0) {
        [NSTimer scheduledTimerWithTimeInterval:interval repeats:NO block:^(NSTimer * _Nonnull timer) {
            if(_isLogOn) NSLog(@"定时器触发停止搜索");
            [weakself stopScan];
            [timer invalidate];
        }];
    }
    if(_isLogOn) {
        NSString *str = [NSString stringWithFormat:@",%f秒后自动停止搜索",interval];
        NSLog(@"开始搜索%@",interval>0?str:@"");
    }
    
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@NO}];
}

-(void)stopScan{
    
    [self.centralManager stopScan];
}

#pragma mark  - CBCentralManagerDelegate method


//init中央设备结果回调
- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (_centralManager.state==5) {//CBManagerStatePoweredOn 或者 CBCentralManagerStatePoweredOn
        if(_isLogOn) NSLog(@"本地蓝牙中央设备状态正常");
    }else{
        if(_isLogOn) NSLog(@"蓝牙状态异常:====[%ld]====",(long)_centralManager.state);
    }
}

//启动搜索的结果回调
- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)peripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    if (peripheral==nil || peripheral.name==nil || [[peripheral.name stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@""]) {
#ifdef DEBUG
        if(_isLogOn) NSLog(@"└┈搜索到设备:%@(名称为空)",peripheral.name);
#endif
        return;
    }
    //过滤当次搜索重复的设备
    NSString *name = [_searchedDeviceUUIDArray valueForKey:[peripheral.identifier UUIDString]];
    if (name!=nil) {
#ifdef DEBUG
        if(_isLogOn) NSLog(@"└┈搜索到设备:%@(重复)",peripheral.name);
#endif
        return;
    }else{
        [_searchedDeviceUUIDArray setValue:peripheral.name forKey:[peripheral.identifier UUIDString]];
    }

    if(_FilterBleNameArray!=nil){
        int i = 0;
        for (NSString* name in _FilterBleNameArray) {
            if([peripheral.name containsString:name])
                break;
            i++;
        }
        if (i==[_FilterBleNameArray count]) {
            return;
        }
    }
    
    __weak typeof(self) weakself = self;
    //组装外设对象
    SimplePeripheral *simplePeripheral = [_Device_dict valueForKey:[peripheral.identifier UUIDString]];
    //从外设对象池中判断是否已经有这个key，有的话取出来。没有就新建
    if(simplePeripheral==nil){
        simplePeripheral = [[SimplePeripheral alloc] initWithCentralManager:_centralManager];
        [_Device_dict setValue:simplePeripheral forKey:[peripheral.identifier UUIDString]];
        
    }
    
    if(_isLogOn) NSLog(@"└┈搜索到设备:%@(上报应用层)",peripheral.name);
    
    [simplePeripheral setPeripheral:peripheral];
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (weakself.MysearchBLEBlock) {
            weakself.MysearchBLEBlock(simplePeripheral);
        }
    });
}



#pragma mark - 静态方法
#pragma mark 

+ (NSString *)NSData2hexString:(NSData *)sourceData
{
    Byte *inBytes = (Byte *)[sourceData bytes];
    NSMutableString *resultData = [[NSMutableString alloc] initWithCapacity:2048];
    
    for(NSInteger counter = 0; counter < [sourceData length]; counter++)
        [resultData appendFormat:@"%02X",inBytes[counter]];
    
    return resultData;
}

+ (NSData *)hexString2NSData:(NSString *)hexString
{
    Byte tmp, result;
    Byte *sourceBytes = (Byte *)[hexString UTF8String];
    
    NSMutableData *resultData = [[NSMutableData alloc] init];
    
    for(NSInteger i=0; i<strlen((char*)sourceBytes); i+=2) {
        tmp = sourceBytes[i];
        if(tmp > '9')
            tmp = toupper(tmp) - 'A' + 0x0a;
        else
            tmp &= 0x0f;
        
        result = tmp <<= 4;
        
        tmp = sourceBytes[i+1];
        if(tmp > '9')
            tmp = toupper(tmp) - 'A' + 0x0a;
        else
            tmp &= 0x0f;
        result += tmp;
        [resultData appendBytes:&result length:1];
    }
    
    return resultData;
}

/**
 * 计算两组byte数组异或后的值。两组的大小要一致。
 * @param bytesData1 NSData1
 * @param bytesData2 NSData2
 * @return    异或后的NSData
 */
+(NSData *)BytesData:(NSData *)bytesData1 XOR:(NSData *)bytesData2
{
    Byte *bytes1 = (Byte *)[bytesData1 bytes];
    Byte *bytes2 = (Byte *)[bytesData2 bytes];
    int len1 = (int)[bytesData1 length];
    int len2 = (int)[bytesData2 length];
    if (len1 != len2) {
        NSLog(@"长度不一致。不能进行模二加！尝试取最小的那一组bytes的长度");
        if (len1 > len2) {
            len1 = len2;
        }
    }
    
    Byte ByteXOR[len1];
    Byte temp1;
    Byte temp2;
    Byte temp3;
    for (int i = 0; i < len1; i++) {
        temp1 = bytes1[i];
        temp2 = bytes2[i];
        temp3 = (temp1 ^ temp2);
        ByteXOR[i] = temp3;
    }
    return [NSData dataWithBytes:ByteXOR length:len1];
}


//计算一个NSData逐个字节异或后的值
+(Byte) XOR:(NSData *)sourceData
{
    Byte *inData = (Byte *)[sourceData bytes];
    int len = (int)[sourceData length];
    Byte outData = 0x00;
    for (int i = 0; i < len; i++) {
        outData = (outData^inData[i]);
    }
    return outData;
}


+(Byte) XOR:(Byte *)sourceBytes offset:(int)offset length:(int)len{
    
    Byte tmp=0x00;
    for (int i = offset; i < len; i++) {
        tmp = (tmp^sourceBytes[i]);
    }
    return tmp;
}

//将两个字节3X 3X 转换--》XX（一个字节）（例如0x31 0x3b ----》 0x1b ）
+(NSData *)twoOneWith3xString:(NSString *)_3xString
{
    NSData *_3xdata = [_3xString dataUsingEncoding:NSUTF8StringEncoding];
    return [self twoOneWith3xData:_3xdata];
}

//将两个字节3X 3X 转换--》XX（一个字节）（例如0x31 0x3b ----》 0x1b ）
+(NSData *)twoOneWith3xData:(NSData *)_3xData
{
    int len = (int)[_3xData length];
    Byte *inData = (Byte*)[_3xData bytes];
    if(len%2!=0)
        return nil;
    Byte outData[len/2];
    for (int i = 0,j = 0; i < len; j++,i+=2) {
        outData[j] = (Byte)(((inData[i]&0x0000000f)<<4) |(inData[i+1]&0x0000000f));
    }
    return [NSData dataWithBytes:outData length:len/2];
}

//将XX（一个字节） 转换--》3x 3x （例如 0x1b ----》 0x31 0x3b 并显示成字符"1;"）
+(NSString *)oneTwo3xString:(NSData *)sourceData
{
    int len = (int)[sourceData length];
    Byte *inData = (Byte*)[sourceData bytes];
    Byte outData[len*2+1];
    for (int i =0,j=0; i<len; i++,j+=2) {
        outData[j] = (Byte)(((inData[i]&0x000000f0)>>4)+0x30);
        outData[j+1] = (Byte)((inData[i]&0x0000000f)+0x30);
    }
    outData[len*2]=0;
    return [NSString stringWithCString:(char*)outData encoding:NSUTF8StringEncoding];
}


/*
 * 将4个字节转换为float数据
 * @param src                 字节数组指针
 * @param offset              字节数组的位移
 * @param srcIsBigEnddian     指示输入数组是否为大端表示，如果YES，此方法内部实现将会转为小端表示。
 * @return  浮点数值，结果为小端表示
 */
+(float)bytes2float:(Byte *)inbytes offset:(int)offset srcIsBigEnddian:(BOOL)srcIsBigEnddian{

    union bytesFloatConvert
    {
        Float32 floatValue;
        Byte bytes[4];
        uint32_t intValue;
    }c;
    memcpy(c.bytes, inbytes+offset, 4);
    if (srcIsBigEnddian) {
        c.intValue = CFSwapInt32(c.intValue);
    }
    return c.floatValue;
}

/*
 * 将float数据转为4个字节的内存表示
 * @param value              整数数值
 * @param resultIsBigEndian  结果是否需要为大端表示。
 * @return  4字节的NSData
 */
+(NSData *)float2data:(float)value resultIsBigEndian:(BOOL)resultIsBigEndian{
    
    union bytesFloatConvert
    {
        Float32 floatValue;
        Byte bytes[4];
        uint32_t intValue;
    }c;
    c.floatValue = value;
    if (resultIsBigEndian) {
        c.intValue =  CFSwapInt32(c.intValue);
    }
    return [NSData dataWithBytes:c.bytes length:4];
}

/*
 * @param value              整数数值
 * @param resultIsBigEndian  结果是否需要为大端表示。
 * @return  4字节的NSData
 */
+(NSData *)integer2data:(int)value resultIsBigEndian:(BOOL)resultIsBigEndian{
    
    union bytesFloatConvert
    {
        uint32_t intValue;
        Byte bytes[4];
    }c;
    c.intValue = resultIsBigEndian?CFSwapInt32(value):value;
    return [NSData dataWithBytes:c.bytes length:4];
}

/*
 * @param src                 字节数组指针
 * @param offset              字节数组的位移
 * @param srcIsBigEnddian     输入数组是否为大端表示，如果是，此方法内部实现将会转为小端表示。
 * @return  整数数值，结果为小端表示
 */
+(int)bytes2integer:(Byte *)src offset:(int)offset srcIsBigEnddian:(BOOL)srcIsBigEnddian{
    
    union bytesFloatConvert
    {
        uint32_t intValue;
        Byte bytes[4];
    }c;
    memcpy(c.bytes, src+offset, 4);
    return srcIsBigEnddian?CFSwapInt32(c.intValue):c.intValue;
}

@end
