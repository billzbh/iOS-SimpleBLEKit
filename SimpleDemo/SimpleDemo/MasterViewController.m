//
//  MasterViewController.m
//  SimpleDemo
//
//  Created by zbh on 17/3/15.
//  Copyright © 2017年 hxsmart. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import <SimpleBLEKit/BLEManager.h>

@interface MasterViewController ()

@property (strong,atomic) NSMutableArray *objects;
@end

@implementation MasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    UIBarButtonItem *disconnectAllButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(disconnectAll:)];
    self.navigationItem.leftBarButtonItem = disconnectAllButton;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchBLE:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    [self startSearch];
}


- (void)viewWillAppear:(BOOL)animated {
    self.clearsSelectionOnViewWillAppear = self.splitViewController.isCollapsed;
    [super viewWillAppear:animated];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)disconnectAll:(id)sender{
    
    UIAlertController *alertController = nil;
    alertController = [UIAlertController alertControllerWithTitle:@"提示" message:@"是否确定断开所有设备的连接" preferredStyle:UIAlertControllerStyleAlert];
    
    //取消按钮
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        
    }];
    [alertController addAction:cancelAction];
    //确定按钮
    UIAlertAction *destructiveAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[BLEManager getInstance] stopScan];
        [[BLEManager getInstance] disconnectAll];
    }];
    [alertController addAction:destructiveAction];
    [self presentViewController:alertController animated:YES completion:nil];
}


-(void)searchBLE:(id)sender{
    [self startSearch];
}

-(void)startSearch{
    if (!self.objects) {
        self.objects = [[NSMutableArray alloc] init];
    }else{
        [self.objects removeAllObjects];
        [self.tableView reloadData];
    }
    
    [[BLEManager getInstance] stopScan];
    [[BLEManager getInstance] setServiceUUIDsForSystemConnectdDevices:@[@"FFF0",@"18F0",@"180A"]];//参数是设备内的serviceuuid其中一个
    [[BLEManager getInstance] startScan:^(SimplePeripheral * _Nonnull peripheral) {
        
        if([self.objects containsObject:peripheral])
            return;
        [self.objects insertObject:peripheral atIndex:0];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } nameFilter:nil/*@[@"iMate",@"K203",@"HxBluetooth",@"JXNX"]*/  timeout:300];
}


#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        
        SimplePeripheral *object = self.objects[indexPath.row];
        DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        [controller setWeakMasterself:self];
        [controller setSelectedPeripheral:object];
        
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

-(void)connectStatus
{

    DetailViewController *controller = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    [controller.connectOrDisconnect setTitle:[controller.selectedPeripheral isConnected]?@"断开设备":@"连接设备" forState:UIControlStateNormal];
    controller.connectOrDisconnect.tag = [controller.selectedPeripheral isConnected]?1:0;
    
    [self.tableView reloadData];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.objects.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    SimplePeripheral *object = self.objects[indexPath.row];
    cell.textLabel.text = [object getPeripheralName];
    cell.accessoryType = [object isConnected]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
    return cell;
}


//- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
//    // Return NO if you do not want the specified item to be editable.
//    return YES;
//}


//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
//        [self.objects removeObjectAtIndex:indexPath.row];
//        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
//    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
//        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
//    }
//}


@end
