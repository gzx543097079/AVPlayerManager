//
//  ViewController.m
//  AVPlayerManager
//
//  Created by ihope99 on 2017/9/6.
//  Copyright © 2017年 com.gzx. All rights reserved.
//

#import "ViewController.h"
#import "GZXPlayerView.h"
#import "AppDelegate.h"

@interface ViewController ()

@property (nonatomic,strong)GZXPlayerView *mGzxPlayView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    appDelegate.isFull = YES;
    

    self.mGzxPlayView = [[GZXPlayerView alloc]initWithFrame:CGRectMake(0, 0,self.view.frame.size.width, 200)];
    [self.view addSubview:self.mGzxPlayView];
    
    ///顺序不能错
    self.mGzxPlayView.rootCtrl = self;
    self.mGzxPlayView.mFatherView = self.view;
    self.mGzxPlayView.mVideoUrlStr = @"http://ywd.zai0312.com/data/upload/admin/20170419/58f5c07c7d946.mp4";//特意弄了一个流量小的服务器测试网速不好的情况

    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
