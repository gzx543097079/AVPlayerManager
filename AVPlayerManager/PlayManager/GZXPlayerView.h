//
//  GZXPlayerView.h
//  AVPlayerDemo
//
//  Created by ihope99 on 2017/7/31.
//  Copyright © 2017年 GYP. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "AFNetworkReachabilityManager.h"




@interface GZXPlayerView : UIView

///是否在4G状态下播放
@property (nonatomic,assign,)BOOL is_Net4G_Play;
///是否在wifi 状态下播自动放
@property (nonatomic,assign)BOOL is_NetWifi_play;
///播放的链接
@property (nonatomic,copy)NSString *mVideoUrlStr;
///是否全屏
@property (nonatomic,assign)BOOL isFullScreen;
///播放的链接
@property (nonatomic,copy)NSString *mDefImageString;

@property (nonatomic,weak)UIViewController *rootCtrl;
@property (nonatomic,weak)UIView *mFatherView;

@property (nonatomic,copy)void(^ChangeFrameBlock)(CGRect changeFrame);



///切换横竖屏
- (void)changeRotate:(UIDeviceOrientation)interfaceOrientation;
#pragma mark - 进入后台
-(void)appDidEnterBackground;
#pragma mark - 进入前台
- (void)appDidEnterPlayGround;

-(void)Pause;
-(void)Cancel;

@end
