//
//  ViewController.m
//  LLFMDB
//
//  Created by 嘚嘚以嘚嘚 on 2018/5/20.
//  Copyright © 2018年 嘚嘚以嘚嘚. All rights reserved.
//

#import "ViewController.h"
#import "GoodsActiveItem.h"
#import "LLFMDB.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    GoodsActiveItem * item = [[GoodsActiveItem alloc] init];
    item.iconImage = @"1";
    item.title = @"2";
    item.oprice = @"3";
    item.price = @"4";
    item.orderID = @"5";
    item.goodsNum = @"6";
    
    LLFMDB * db = [LLFMDB shareDatabase];
    
    //是否存在
    if (![db ll_isExistTable:@"lldb"]) {
        //创建数据库
        [db ll_createTable:@"lldb" dicOrModel:item];
    }
    
    //增加数据
    [db ll_insertTable:@"lldb" dicOrModel:item];
    
    NSLog(@"表中字段名:%@",[db ll_columnNameArray:@"lldb"]);
    
    NSLog(@"表中一共多少数据:%d",[db ll_tableItemCount:@"lldb"]);
    
    NSLog(@"查询表中数据:%@",[db ll_lookupTable:@"lldb" dicOrModel:item whereFormat:[NSString stringWithFormat:@"where orderID = '%@'",item.orderID]]);
    
    //更新数据
    [db ll_updateTable:@"lldb" dicOrModel:item whereFormat:[NSString stringWithFormat:@"where orderID = '%@'",item.orderID]];
    //删除数据
    [db ll_deleteTable:@"lldb" whereFormat:[NSString stringWithFormat:@"where orderID = '%@'",item.orderID]];
    
    
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
