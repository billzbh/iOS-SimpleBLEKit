//
//  DetailViewController.m
//  SimpleDemo
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "DetailViewController.h"
#import <SimpleBLEKit/BLEManager.h>

@interface DetailViewController () <UITextFieldDelegate>

@end

@implementation DetailViewController

#pragma mark - UI action 外设设置

- (IBAction)LogOn:(UISwitch *)sender {
    [self.selectedPeripheral setIsLog:sender.isOn];
}

- (IBAction)AutoReconnect:(UISwitch *)sender {
    [self.selectedPeripheral setIsAutoReconnect:sender.isOn];
}

- (IBAction)writeResponseType:(UISwitch *)sender {
    if (sender.isOn) {
        [self.selectedPeripheral setResponseType:CBCharacteristicWriteWithResponse];
    }else{
        [self.selectedPeripheral setResponseType:CBCharacteristicWriteWithoutResponse];
    }
}

- (IBAction)ConnectOrDisconnectAction:(id)sender {
    

    if(![_selectedPeripheral isKindOfClass:[SimplePeripheral class]])
        return;
    NSString * serviceuuid =  self.serviceUuid.text;
    NSString * notifyuuid =  self.notifyUuid.text;
    NSString * writeuuid =  self.writeUuid.text;
    NSString * mtuStr =  self.MTU.text;
    int mtu = [mtuStr intValue];
    //    NSString * regularExp =  self.regularExp.text;
    
    
    
    
    
    [[BLEManager getInstance] stopScan];
    if(self.connectOrDisconnect.tag == 1){
        [_selectedPeripheral disconnect];
        return;
    }
    //发起连接前，对外设做各项设置(可选)
    if (_isSetMTU.isOn) {
        [_selectedPeripheral setMTU:mtu];
    }
    NSData *ackData = [NSData dataWithBytes:"\x06" length:1];
    [_selectedPeripheral setAck:YES withData:ackData withACKEvaluator:^BOOL(NSData * _Nullable inputData) {
        if (inputData.length>0) {
            return YES;
        }
        return NO;
    }];
    
    
    
    //以下的方法连接前必须调用
    [_selectedPeripheral setServiceUUID:serviceuuid Notify:notifyuuid Write:writeuuid];
    //收包完整性验证: 传入block，写上收包完整的逻辑，返回YES时认为包完整。
    [_selectedPeripheral setResponseEvaluator:^BOOL(NSData * _Nullable inputData) {
        
        Byte *packBytes = (Byte*)[inputData bytes];
        if (packBytes[0]!=0x02) {
            return NO;
        }
        int dataLen;
        int packDataLen = (int)inputData.length;
        Byte *startDataPotint;
        if (packDataLen < 4) {
            return NO;
        }
        
        if ( packBytes[1] == 0x00 ) {
            if(packBytes[2] == 0xFF) {
                if ( packDataLen < 6)
                    return NO;
                dataLen = packBytes[4]*256+packBytes[5];
                if ( dataLen + 8 > packDataLen ) {
                    return NO;
                }
                startDataPotint = &packBytes[6];
            }
            else {
                dataLen = packBytes[2]*256+packBytes[3];
                if ( dataLen + 6 > packDataLen ) {
                    return NO;
                }
                startDataPotint = &packBytes[4];
            }
        }
        else {
            dataLen = packBytes[1];
            if ( dataLen + 4 > packDataLen ) {
                return NO;
            }
            startDataPotint = &packBytes[2];
        }
        
        if (startDataPotint[dataLen] != 0x03) {
            return NO;
        }
        
        Byte checkCode=0;
        for ( NSInteger i=0;i<dataLen+2;i++ ){
            
            checkCode^=startDataPotint[i];
        }
        
        if ( checkCode ) {
            return NO;
        }
        
        return YES;
        
    }];
    //开始连接
    [_selectedPeripheral connectDevice:^(BOOL isPrepareToCommunicate) {
        
        NSLog(@"设备%@",isPrepareToCommunicate?@"已连接":@"已断开");
        
        [self.connectOrDisconnect setTitle:isPrepareToCommunicate?@"断开设备":@"连接设备" forState:UIControlStateNormal];
        self.connectOrDisconnect.tag = isPrepareToCommunicate?1:0;
        [_weakMasterself connectStatus];
    }];
}


- (IBAction)setSendMTU:(UISwitch *)sender {
    [self.MTU setEnabled:sender.isOn];
    if (sender.isOn) {
        [self.MTU becomeFirstResponder];
    }
}

#pragma mark - 发送接收数据
- (IBAction)sendHexDataAction:(id)sender {
    
    NSString *hexString = self.sendHexString.text;
    NSData *data = [BLEManager twoOneData:hexString];
    [_selectedPeripheral sendData:data receiveData:^(NSData * _Nullable outData, NSString * _Nullable error) {
        
        if(error){
            self.notifyTextview.text = [NSString stringWithFormat:@"%@",error];
        }else{
            NSString *out = [NSString stringWithFormat:@"%@从%@收到的包完整数据:\n%@\n",[self getTimeNow],[_selectedPeripheral getPeripheralName],[BLEManager oneTwoData:outData]];
            [self.notifyTextview.textStorage.mutableString appendString:out];
        }
        
    } Timeout:-1];
}











//以下都和外设方法的逻辑无关。不用看。
#pragma mark - Managing the detail item

- (void)setSelectedPeripheral:(SimplePeripheral *)newDetailItem {
    if (_selectedPeripheral != newDetailItem) {
        _selectedPeripheral = newDetailItem;
        [_selectedPeripheral setIsLog:YES];
        // Update the view.
        [self configureView];
    }
}

- (NSString *)getTimeNow
{
    NSString* date;
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc ] init];
    [formatter setDateFormat:@"YYYY-MM-dd hh:mm:ss:SSS"];
    date = [formatter stringFromDate:[NSDate date]];
    return [[NSString alloc] initWithFormat:@"%@", date];
}


#pragma mark - 解决键盘遮挡，与蓝牙逻辑无关。
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    CGRect frame = textField.frame;
    
    CGFloat heights = self.view.frame.size.height;
    
    // 当前点击textfield的坐标的Y值 + 当前点击textFiled的高度 - （屏幕高度- 键盘高度 - 键盘上tabbar高度）
    // 在这一部 就是了一个 当前textfile的的最大Y值 和 键盘的最全高度的差值，用来计算整个view的偏移量
    int offset = frame.origin.y + 42- ( heights - 216.0-35.0);
    NSLog(@"设备:%@",[UIDevice currentDevice].model);
    if([[UIDevice currentDevice].model containsString:@"iPad"]){
        
        heights = self.view.frame.size.width;
        offset = frame.origin.y + 42- ( heights - 320.0-35.0);
    }

    NSTimeInterval animationDuration = 0.30f;
    
    [UIView beginAnimations:@"ResizeForKeyBoard" context:nil];
    
    [UIView setAnimationDuration:animationDuration];
    
    float width = self.view.frame.size.width;
    
    float height = self.view.frame.size.height;
    
    if(offset > 0)
    {
        
        CGRect rect = CGRectMake(0.0f, -offset,width,height);
        
        self.view.frame = rect;
        
    }
    [UIView commitAnimations];
}


- (void)textFieldDidEndEditing:(UITextField *)textField{
    [self.view endEditing:YES];
    
    NSTimeInterval animationDuration = 0.30f;
    
    [UIView beginAnimations:@"ResizeForKeyboard" context:nil];
    
    [UIView setAnimationDuration:animationDuration];
    
    CGRect rect = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
    
    self.view.frame = rect;
    
    [UIView commitAnimations];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [self.view endEditing:YES];
    NSTimeInterval animationDuration = 0.30f;
    
    [UIView beginAnimations:@"ResizeForKeyboard" context:nil];
    
    [UIView setAnimationDuration:animationDuration];
    
    CGRect rect = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
    
    self.view.frame = rect;
    [UIView commitAnimations];
    return YES;
}

////点击空白恢复
//-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
//
//{
//    
//    NSLog(@"touchesBegan");
//    
//    [self.view endEditing:YES];
//    
//    NSTimeInterval animationDuration = 0.30f;
//    
//    [UIView beginAnimations:@"ResizeForKeyboard" context:nil];
//    
//    [UIView setAnimationDuration:animationDuration];
//    
//    CGRect rect = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
//    
//    self.view.frame = rect;
//    
//    [UIView commitAnimations];
//    
//}

- (void)configureView {//配置当前视图
    // Update the user interface for the detail item.
    if (_selectedPeripheral) {
        self.navigationItem.title =[_selectedPeripheral getPeripheralName];
    }
    [self.connectOrDisconnect setTitle:[_selectedPeripheral isConnected]?@"断开设备":@"连接设备" forState:UIControlStateNormal];
    self.connectOrDisconnect.tag = [_selectedPeripheral isConnected]?1:0;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.sendHexString.delegate = self;
    self.regularExp.delegate = self;
    self.writeUuid.delegate = self;
    self.notifyUuid.delegate = self;
    self.serviceUuid.delegate = self;
    
    [self.SendHexDataButton.layer setMasksToBounds:YES];//设置按钮的圆角半径不会被遮挡
    [self.SendHexDataButton.layer setCornerRadius:4];
    [self.SendHexDataButton.layer setBorderWidth:1];//设置边界的宽度
    //设置按钮的边界颜色
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGColorRef color = CGColorCreate(colorSpaceRef, (CGFloat[]){0,0.5,1,1});
    [self.SendHexDataButton.layer setBorderColor:color];
    
    CGColorRelease(color);
    CGColorSpaceRelease(colorSpaceRef);
    
    [self configureView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
