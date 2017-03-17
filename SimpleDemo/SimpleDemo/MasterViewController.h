//
//  MasterViewController.h
//  SimpleDemo
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SimpleBLEKit/SimplePeripheral.h>
@class DetailViewController;

@interface MasterViewController : UITableViewController

@property (strong, nonatomic) DetailViewController *detailViewController;

-(void)connectStatus;
@end

