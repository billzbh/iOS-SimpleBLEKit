//
//  BLEManager.m
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "BLEManager.h"
#import "SimplePeripheralPrivate.h"

@interface BLEManager () <CBCentralManagerDelegate>{
    BOOL isPowerON;
}


@property (strong, nonatomic) CBCentralManager  *centralManager;
@property (nonatomic,copy) SearchBlock MysearchBLEBlock;
@property (strong,nonatomic) NSMutableDictionary *Device_dict;
@property (strong, nonatomic) NSMutableDictionary  *searchedDeviceUUIDArray;
@property (assign,nonatomic) BOOL isLogOn;

@end

@implementation BLEManager

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    
    _Device_dict = [[NSMutableDictionary alloc] init];
    dispatch_queue_t _centralManagerQueue = dispatch_queue_create("com.zbh.SimpleBLEKit.centralManagerQueue", 0);
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:_centralManagerQueue];
    isPowerON = NO;
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
}


+ (BLEManager *)getInstance
{
    static BLEManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[BLEManager alloc] init];
//        NSLog(@"SimpleBLEKit Version: V1.17.314");
        NSLog(@"SimpleBLEKit Version: V1.17.407");
    });
    return sharedInstance;
}

//如果外设名称不同，可以通过这个获取到已连接的外设
-(SimplePeripheral *)connectPeripheral:(NSString *)BLE_Name{
    NSArray *array = [_Device_dict allValues];
    for (SimplePeripheral *peripheral in array) {
        if ([peripheral isConnected] && [[peripheral getPeripheralName] hasPrefix:BLE_Name]) {
            return peripheral;
        }
    }
    return nil;
}

//返回本管理对象BLEManager的所有已连接对象
-(NSArray<SimplePeripheral *>*)connectPeripherals
{
    return [self connectPeripheralsWithServices:nil];
}

//如果serviceUUIDs不为nil，调用系统的retrieveConnectedPeripheralsWithServices返回已经连接的设备
//如果serviceUUIDs为nil，返回本管理对象BLEManager的所有已连接对象
-(NSArray<SimplePeripheral *>*)connectPeripheralsWithServices:(NSArray<CBUUID *> *)serviceUUIDs
{
    
    NSArray *array;
    NSMutableArray *connectedDevices;
    if (serviceUUIDs==nil) {
        
        array = [_Device_dict allValues];
        connectedDevices = [NSMutableArray arrayWithArray:array];
        for (SimplePeripheral *peripheral in array) {
            if (![peripheral isConnected]) {
                [connectedDevices removeObject:peripheral];
            }
        }
        
    }else{
        array = [_centralManager retrieveConnectedPeripheralsWithServices:serviceUUIDs];
        connectedDevices = [NSMutableArray arrayWithCapacity:10];
        for (CBPeripheral *cbperipheral in array) {
            
            //组装外设对象
            SimplePeripheral *simplePeripheral = [_Device_dict valueForKey:[cbperipheral.identifier UUIDString]];
            //从外设对象池中判断是否已经有这个key，有的话取出来。没有就新建
            if(simplePeripheral==nil){
                simplePeripheral = [[SimplePeripheral alloc] initWithCentralManager:_centralManager];
            }
            [connectedDevices addObject:simplePeripheral];
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

-(void)disconnectAll{
    
    for (NSString *key in _Device_dict) {
        
        SimplePeripheral *peripheral = _Device_dict[key];
        if ([peripheral isConnected]) {
            [peripheral disconnect];
        }
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


-(void)startScan:(SearchBlock)searchBLEBlock timeout:(NSTimeInterval)interval
{
    _MysearchBLEBlock = searchBLEBlock;
    _centralManager.delegate = self;
    if (_searchedDeviceUUIDArray==nil) {
        _searchedDeviceUUIDArray = [[NSMutableDictionary alloc] init];
    }else{
        [_searchedDeviceUUIDArray removeAllObjects];
    }
    //将已经连接的设备也上报
    __weak typeof(self) weakself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(_isLogOn) NSLog(@"搜索前，上报设备池中已连接的外设...");
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
    if (interval>0) {
        [NSTimer scheduledTimerWithTimeInterval:interval repeats:NO block:^(NSTimer * _Nonnull timer) {
            if(_isLogOn) NSLog(@"定时器触发停止搜索");
            [weakself stopScan];
            [timer invalidate];
            timer = nil;
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
    if (_centralManager.state==5) {//CBManagerStatePoweredOn
        if(_isLogOn) NSLog(@"本地蓝牙状态正常");
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
        if(_isLogOn) NSLog(@"└┈搜索到设备:%@(名称为空)",peripheral.name);
        return;
    }
    //过滤当次搜索重复的设备
    NSString *name = [_searchedDeviceUUIDArray valueForKey:[peripheral.identifier UUIDString]];
    if (name!=nil) {
        if(_isLogOn) NSLog(@"└┈搜索到设备:%@(重复)",peripheral.name);
        return;
    }else{
        [_searchedDeviceUUIDArray setValue:peripheral.name forKey:[peripheral.identifier UUIDString]];
    }
    
    
    //组装外设对象
    SimplePeripheral *simplePeripheral = [_Device_dict valueForKey:[peripheral.identifier UUIDString]];
    //从外设对象池中判断是否已经有这个key，有的话取出来。没有就新建
    if(simplePeripheral==nil){
        simplePeripheral = [[SimplePeripheral alloc] initWithCentralManager:_centralManager];
        [_Device_dict setValue:simplePeripheral forKey:[peripheral.identifier UUIDString]];
        
    }
    if(_isLogOn) NSLog(@"└┈搜索到设备:%@(上报应用层)",peripheral.name);
    [simplePeripheral setPeripheral:peripheral];
    __weak typeof(self) weakself = self;
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

@end
