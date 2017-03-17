//
//  BLEManager.m
//  SimpleBLEKit
//
//  Created by zbh on 17/3/14.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "BLEManager.h"

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
        NSLog(@"SimpleBLEKit Version: V1.17.314");
    });
    return sharedInstance;
}


-(void)DisconnectAll{
    
    for (NSString *key in _Device_dict) {
        
        SimplePeripheral *peripheral = _Device_dict[key];
        if ([peripheral isConnected]) {
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
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(_isLogOn) NSLog(@"搜索前，上报设备池中已连接的外设...");
        for (NSString *key in _Device_dict) {
            
            SimplePeripheral *peripheral = _Device_dict[key];
            if ([peripheral isConnected]) {
                if(_isLogOn) NSLog(@"上报%@",[peripheral getPeripheralName]);
                if (_MysearchBLEBlock) {
                    _MysearchBLEBlock(peripheral);
                }
            }
        }
    });
    if (interval>0) {
        [NSTimer scheduledTimerWithTimeInterval:interval repeats:NO block:^(NSTimer * _Nonnull timer) {
            if(_isLogOn) NSLog(@"定时器触发停止搜索");
            [self stopScan];
        }];
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
        if(_isLogOn) NSLog(@"本地蓝牙状态异常");
    }
}

//启动搜索的结果回调
- (void) centralManager:(CBCentralManager *)central
  didDiscoverPeripheral:(CBPeripheral *)peripheral
      advertisementData:(NSDictionary *)advertisementData
                   RSSI:(NSNumber *)RSSI
{
    if (peripheral==nil || peripheral.name==nil || [[peripheral.name stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@""]) {
        return;
    }
    //上报发现的设备
    if(_isLogOn) NSLog(@"搜索到设备:%@",peripheral.name);
    
    //过滤当次搜索重复的设备
    NSString *name = [_searchedDeviceUUIDArray valueForKey:[peripheral.identifier UUIDString]];
    if (name!=nil) {
        if(_isLogOn) NSLog(@"此设备 %@ 的UUID相同，此次搜索不再上报",peripheral.name);
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
    else{
        if(_isLogOn) NSLog(@"这是设备池中持有的对象");
    }
    [simplePeripheral setPeripheral:peripheral];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_MysearchBLEBlock) {
            _MysearchBLEBlock(simplePeripheral);
        }
    });
}



#pragma mark - 静态方法
#pragma mark 

+ (NSString *)oneTwoData:(NSData *)sourceData
{
    Byte *inBytes = (Byte *)[sourceData bytes];
    NSMutableString *resultData = [[NSMutableString alloc] initWithCapacity:2048];
    
    for(NSInteger counter = 0; counter < [sourceData length]; counter++)
        [resultData appendFormat:@"%02X",inBytes[counter]];
    
    return resultData;
}

+ (NSData *)twoOneData:(NSString *)sourceString
{
    Byte tmp, result;
    Byte *sourceBytes = (Byte *)[sourceString UTF8String];
    
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
