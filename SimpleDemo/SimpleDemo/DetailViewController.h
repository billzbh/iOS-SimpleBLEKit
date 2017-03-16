//
//  DetailViewController.h
//  SimpleDemo
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SimpleBLEKit/SimplePeripheral.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) SimplePeripheral *selectedPeripheral;

@property (weak, nonatomic) IBOutlet UITextField *serviceUuid;
@property (weak, nonatomic) IBOutlet UITextField *notifyUuid;
@property (weak, nonatomic) IBOutlet UITextField *writeUuid;
@property (weak, nonatomic) IBOutlet UITextField *regularExp;
@property (weak, nonatomic) IBOutlet UITextField *sendHexString;
@property (weak, nonatomic) IBOutlet UITextView *notifyTextview;
@property (weak, nonatomic) IBOutlet UIButton *connectOrDisconnect;
@property (weak, nonatomic) IBOutlet UIButton *SendHexDataButton;

@property (weak, nonatomic) IBOutlet UISwitch *isSetMTU;
@property (weak, nonatomic) IBOutlet UITextField *MTU;

@end

