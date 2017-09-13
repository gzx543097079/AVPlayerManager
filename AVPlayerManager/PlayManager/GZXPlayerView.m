//
//  GZXPlayerView.m
//  AVPlayerDemo
//
//  Created by ihope99 on 2017/7/31.
//  Copyright © 2017年 GYP. All rights reserved.
//

#import "GZXPlayerView.h"
#import "Masonry.h"
#import "AppDelegate.h"
#import "NSObject+XWAdd.h"
#import "AFNetworkReachabilityManager.h"


#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
#define WKS(weakSelf)     __weak typeof(self)weakSelf = self;


/**视频播放的状态**/
typedef NS_ENUM(NSInteger,GZXPlayerState) {
    GZXPlayerStateNomer = 0,
    GZXPlayerStateFailed = 1,        // 播放失败
    GZXPlayerStateBuffering = 2,     // 缓冲中
    GZXPlayerStateReadyToPlay = 3,  //将要播放
    GZXPlayerStatePlaying = 4,       // 播放中
    GZXPlayerStateStopped = 5,        //暂停播放
    GZXPlayerStateFinished = 6,       //播放完毕
    GZXPlayerStateInterrupt = 7 //播放异常中断
} ;


@interface GZXPlayerView ()

///视频加载菊花
@property (nonatomic, strong) UIActivityIndicatorView *mActivityView;
///底部View
@property (nonatomic,strong)UIView *mBottomView;
///播放按钮/暂停按钮
@property (nonatomic,strong)UIButton *mPlayFullButton;
///播放按钮/暂停按钮
@property (nonatomic,strong)UIButton *mPlayButton;
///视频缓存进度条
@property (nonatomic,strong)UIProgressView *mProgessView;
///是否是从后台进入
@property (nonatomic,assign)BOOL is_ExitPlayGround;
///当前网络状态
@property (nonatomic,assign)__block AFNetworkReachabilityStatus NetStatus;
///视频播放进度条
@property (nonatomic,strong)UISlider *mSlider;
///当前播放时间Label
@property (nonatomic,strong)UILabel  *mCurrentTimeLabel;
///总播放时间Label
@property (nonatomic,strong)UILabel  *mTotalTimeLabel;
///切换全屏按钮
@property (nonatomic,strong)UIButton  *mFullScreenButton;
///记录当前缓存的进度
@property (nonatomic,assign)NSTimeInterval mNowloadedTime;
/// 播放器状态
@property (nonatomic, assign) GZXPlayerState   mPlayState;
///进度条是否正在拖拽
@property (nonatomic,assign)BOOL isDragSlider;
///默认的背景图
@property (nonatomic,strong)UIImageView *mBgImageView;;

@property (nonatomic)CGRect mSmallFrame;
@property (nonatomic,strong) AVPlayerItem *mPlayerItem;
@property (nonatomic,strong) AVPlayerLayer *mPlayerLayer;
@property (nonatomic,strong) AVPlayer *mPlayer;

@end


@implementation GZXPlayerView


//修改当前View的Layer类型
+(Class)layerClass{
    return [AVPlayerLayer class];
    
}
-(instancetype)initWithFrame:(CGRect)frame{
    self =  [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.mNowloadedTime = 0;
        self.isDragSlider = NO;
        self.isFullScreen = NO;
        self.is_Net4G_Play = NO;
        self.is_ExitPlayGround = NO;
        self.is_NetWifi_play = YES;
        self.mPlayState = GZXPlayerStateNomer;
        
        [self CreatPalyer];
        [self CreatView];
        [self setTheProgressOfPlayTime];
        //        self.mSmallFrame = frame;
        
        [self MonitorNetChange];
        
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterPlayGround) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        self.mBottomView.hidden = YES;
        
        
#pragma mark - 监听横竖屏切换
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
        
        
        self.mSmallFrame = CGRectMake(self.mSmallFrame.origin.x,self.mSmallFrame.origin.y, kScreenWidth,frame.size.height);
        [self SetNorFrame];
        
    }
    return self;
}


#pragma mark - 开始播放
-(void)Play{
    if (self.mPlayState == GZXPlayerStateNomer || self.mPlayState == GZXPlayerStateFailed) {
        return;
    }
    
    self.mBgImageView.hidden = YES;
    
    if (self.NetStatus == AFNetworkReachabilityStatusReachableViaWiFi) {
        if (self.mPlayer.rate != 1.f && self.isDragSlider == NO) {
            [self.mPlayer play];
            self.mPlayButton.selected = YES;
            self.mPlayFullButton.hidden = YES;
            self.mPlayState = GZXPlayerStatePlaying;
            
            
        }
    }
    else if (self.NetStatus == AFNetworkReachabilityStatusReachableViaWWAN){
        if (self.is_Net4G_Play == YES) {
            if (self.mPlayer.rate != 1.f && self.isDragSlider == NO) {
                [self.mPlayer play];
                self.mPlayButton.selected = YES;
                self.mPlayFullButton.hidden = YES;
                self.mPlayState = GZXPlayerStatePlaying;
            }
        }
        else{
            [self ShowAlertView:@"您当前正在使用移动网络,继续播放将消耗流量"];
        }
        
    }
    self.is_ExitPlayGround = NO;
    
}


#pragma mark - 暂停播放
-(void)Pause{
    [self.mPlayer pause];
    self.mPlayButton.selected = NO;
    self.mPlayFullButton.hidden = NO;
    self.mPlayState = GZXPlayerStateStopped;
    self.is_ExitPlayGround = NO;
}

-(void)MonitorNetChange{
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    // 检测网络连接的单例,网络变化时的回调方法
    __weak typeof(self)weakSelf = self;
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        weakSelf.NetStatus = status;
        if (status == AFNetworkReachabilityStatusReachableViaWiFi) {
            weakSelf.is_Net4G_Play = NO;
            NSLog(@"wifi");
            //如果变化为wifi 就继续缓存
            [weakSelf.mPlayerItem xw_removeObserverBlockForKeyPath:@"loadedTimeRanges"];
            [weakSelf.mPlayerItem xw_addObserverBlockForKeyPath:@"loadedTimeRanges" block:^(id  _Nonnull obj, id  _Nonnull oldVal, id  _Nonnull newVal) {
                [weakSelf SetLoadTimeRanges];
            }];
        }
        else{
            NSLog(@"4G");
            //如果不是WIFI就移除缓存
            //            [self.mPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
            [weakSelf.mPlayerItem xw_removeObserverBlockForKeyPath:@"loadedTimeRanges"];
        }
    }];
    
}

- (void)setMVideoUrlStr:(NSString *)mVideoUrlStr {
    _mVideoUrlStr = mVideoUrlStr;
    
    if ([NSURL URLWithString:mVideoUrlStr]) {
        
        if (self.mPlayerItem) {
            [self.mPlayerItem xw_removeAllObserverBlocks];
            [self.mPlayerItem xw_removeAllNotification];
        }
        
        
        self.mPlayerItem = [AVPlayerItem playerItemWithURL:[NSURL URLWithString:mVideoUrlStr]];
        [self.mPlayer replaceCurrentItemWithPlayerItem:self.mPlayerItem];
        if([[UIDevice currentDevice] systemVersion].floatValue >= 10.0){
            //      增加下面这行可以解决iOS10兼容性问题了
            self.mPlayer.automaticallyWaitsToMinimizeStalling = NO;
        }
        // AVPlayer播放完成通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playDidEnd) name:AVPlayerItemDidPlayToEndTimeNotification object:self.mPlayer.currentItem];
        
        // AVPlayer异常中断
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(playInterrupt)
                                                    name:AVPlayerItemPlaybackStalledNotification
                                                  object:self.mPlayerItem];
#pragma mark - 获取视频大小
        AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL URLWithString:mVideoUrlStr]];
        NSArray *array = asset.tracks;
        CGSize videoSize = CGSizeZero;
        
        for (AVAssetTrack *track in array) {
            if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
                videoSize = track.naturalSize;
            }
        }
        
        
        if (videoSize.width > 0) {
            self.mSmallFrame = CGRectMake(self.mSmallFrame.origin.x,self.mSmallFrame.origin.y, kScreenWidth,videoSize.height *(kScreenWidth/videoSize.width));
            WKS(weakSelf);
            [self mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(weakSelf.mFatherView).with.offset(0);
                make.right.equalTo(weakSelf.mFatherView).with.offset(0);
                make.left.equalTo(weakSelf.mFatherView).with.offset(0);
                make.height.mas_equalTo(videoSize.height *(kScreenWidth/videoSize.width));
            }];
            [self SetNorFrame];

        }
        else{
            WKS(weakSelf);
            [self mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(weakSelf.mFatherView).with.offset(0);
                make.right.equalTo(weakSelf.mFatherView).with.offset(0);
                make.left.equalTo(weakSelf.mFatherView).with.offset(0);
                make.height.mas_equalTo(self.mSmallFrame.size.height);
            }];
            [self SetNorFrame];
        }
        
        
        if (self.ChangeFrameBlock) {
            self.ChangeFrameBlock(self.mSmallFrame);
        }
        __weak typeof(self)weakSelf = self;
#pragma mark --监听缓存
        [weakSelf.mPlayerItem xw_addObserverBlockForKeyPath:@"loadedTimeRanges" block:^(id  _Nonnull obj, id  _Nonnull oldVal, id  _Nonnull newVal) {
            
            [weakSelf SetLoadTimeRanges];
        }];
#pragma mark --监听播放器状态
        [weakSelf.mPlayerItem xw_addObserverBlockForKeyPath:@"status" block:^(id  _Nonnull obj, id  _Nonnull oldVal, id  _Nonnull newVal) {
            [weakSelf SetPlayStatus];
        }];
        
#pragma mark --监听缓存为空
        [weakSelf.mPlayerItem xw_addObserverBlockForKeyPath:@"playbackBufferEmpty" block:^(id  _Nonnull obj, id  _Nonnull oldVal, id  _Nonnull newVal) {
            if (weakSelf.mPlayerItem.playbackBufferEmpty) {
                [weakSelf.mActivityView startAnimating];
                NSLog(@"playbackBufferEmpty");
                weakSelf.mPlayState = GZXPlayerStateBuffering;
                //                [weakSelf loadedTimeRanges];
            }
            
        }];
#pragma mark --监听缓存好了
        [weakSelf.mPlayerItem xw_addObserverBlockForKeyPath:@"playbackLikelyToKeepUp" block:^(id  _Nonnull obj, id  _Nonnull oldVal, id  _Nonnull newVal) {
            if (weakSelf.mPlayerItem.playbackLikelyToKeepUp && self.mPlayState == GZXPlayerStateBuffering){
                NSLog(@"playbackLikelyToKeepUp");
                weakSelf.mPlayState = GZXPlayerStatePlaying;
            }
        }];
        [self setSliderEvent];
    }
    else{
        [self SetNorFrame];
    }
}


-(void)FullPlayAction{
    [self GetButtonShow];
    [self Play];
}

#pragma mark - 播放暂停按钮
-(void)playBtnClick:(UIButton *)button{
    if (button.selected == NO) {
        [self Play];
    }
    else{
        [self Pause];
    }
}
#pragma mark - 全屏按钮
-(void)fullScreenBtnCLick:(UIButton *)button{
    
    if (!self.isFullScreen){
        NSNumber *value = [NSNumber numberWithInt:UIDeviceOrientationLandscapeLeft];
        [[UIDevice currentDevice]setValue:value forKey:@"orientation"];
    }
    else{
        NSNumber *value = [NSNumber numberWithInt:UIDeviceOrientationPortrait];
        [[UIDevice currentDevice]setValue:value forKey:@"orientation"];
    }
}

#pragma mark - 播放异常终端
- (void)playInterrupt {
    NSLog(@"GZXPlayerStateInterrupt == 播放异常中断");
    self.mPlayState = GZXPlayerStateInterrupt;
}
#pragma mark - 播放结束
- (void)playDidEnd{
    
    self.mPlayState = GZXPlayerStateFinished;
    __weak typeof(self)weakSelf = self;
    [weakSelf.mPlayer seekToTime:CMTimeMake(0, 1) completionHandler:^(BOOL finish){
        [weakSelf.mSlider setValue:0.0 animated:NO];
        [weakSelf.mProgessView setProgress:0];
        weakSelf.mCurrentTimeLabel.text = @"00:00";
        [weakSelf Pause];
    }];
}
#pragma mark - UISlider Delegate
-(void)sliderDragValueChange:(UISlider *)sender{
    if (!self.mPlayerItem || ![self.mPlayer currentItem].duration.value || ![self.mPlayer currentItem].duration.timescale) {
        return;
    }
    self.isDragSlider = YES;
    [self SetSliderValue:sender];
    [self.mPlayer pause];
}
-(void)sliderTapValueChange:(UISlider *)sender{
    if (!self.mPlayerItem || ![self.mPlayer currentItem].duration.value || ![self.mPlayer currentItem].duration.timescale) {
        return;
    }
    self.isDragSlider = NO;
    CGFloat current = sender.value;
    CMTime dragTime = CMTimeMake(current, 1);
    __weak typeof(self)weakSelf = self;
    [weakSelf.mPlayer seekToTime:dragTime completionHandler:^(BOOL finished) {
        if (weakSelf.mPlayButton.selected == YES) {
            [weakSelf Play];
        }
    }];
}
-(void)SetSliderValue:(UISlider *)sender{
    CGFloat current = sender.value;
    NSInteger proSec = (NSInteger)current % 60;
    NSInteger proMin = (NSInteger)current / 60;
    self.mCurrentTimeLabel.text = [NSString stringWithFormat:@"%02zd:%02zd", proMin, proSec];
}

//设置播放进度和时间
-(void)setTheProgressOfPlayTime
{
    __weak typeof(self) weakSelf = self;
    [weakSelf.mPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        
        //如果是拖拽slider中就不执行.
        
        if (weakSelf.isDragSlider) {
            return ;
        }
        float current=CMTimeGetSeconds(time);
        if (current) {
            [weakSelf.mSlider setValue:current animated:YES];
        }
        //秒数
        NSInteger proSec = (NSInteger)current%60;
        //分钟
        NSInteger proMin = (NSInteger)current/60;
        weakSelf.mCurrentTimeLabel.text = [NSString stringWithFormat:@"%02zd:%02zd", proMin, proSec];
        if (weakSelf.mNowloadedTime - weakSelf.mSlider.value < 1  && weakSelf.NetStatus == AFNetworkReachabilityStatusReachableViaWWAN && weakSelf.is_Net4G_Play == NO) {
            [weakSelf Pause];
        }
        
    } ];
}


#pragma mark - 进入后台
-(void)appDidEnterBackground{
    [self.mPlayer pause];
    self.is_ExitPlayGround = YES;
    self.mPlayState = GZXPlayerStateStopped;
    
    //    [GViewManager Share].gzxDelegate.isFull = NO;
    
}
#pragma mark - 进入前台
- (void)appDidEnterPlayGround{
    //    [GViewManager Share].gzxDelegate.isFull = YES;
    if (self.mPlayButton.selected  == YES) {
        [self Play];
    }
    else{
        [self Pause];
    }
}

//缓存够了的操作
- (void)loadedTimeRanges
{
    if (self.mPlayState != GZXPlayerStatePlaying &&
        self.mPlayButton.selected == YES) {
        
        
        [self.mPlayer play];
        [self.mActivityView stopAnimating];
    }
}

#pragma mark - 获取缓冲区域
- (float)availableDuration {
    NSArray *loadedTimeRanges = [[self.mPlayer currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}
#pragma mark - 设置缓冲方法
-(void)SetLoadTimeRanges{
    NSTimeInterval timeInterval = [self availableDuration];// 计算缓冲进度
    CMTime duration             = self.mPlayerItem.asset.duration;
    CGFloat totalDuration       = CMTimeGetSeconds(duration);
    [self.mProgessView setProgress:timeInterval/totalDuration animated:NO];
    NSLog(@"当前剩余缓存进度%f",timeInterval - self.mSlider.value);
    self.mNowloadedTime = timeInterval;
    
    if (timeInterval - self.mSlider.value > 5  && self.mPlayState == GZXPlayerStateInterrupt  && self.mPlayFullButton.hidden == YES) {
        [self.mActivityView stopAnimating];
        [self Play];
    }
    
}
#pragma mark - 设置状态
-(void)SetPlayStatus{
    if (self.mPlayer.status == AVPlayerStatusReadyToPlay) {
        NSLog(@"AVPlayerStatusReadyToPlay");
        
        self.mPlayState = GZXPlayerStateReadyToPlay;
        
        CGFloat value = CMTimeGetSeconds(self.mPlayerItem.asset.duration);
        if (value == 0) {
            self.mPlayState = GZXPlayerStateFailed;
        }
        else{
            self.mPlayState = GZXPlayerStateReadyToPlay;//准备好播放
        }
        [self setSliderEvent];
        [self SetRrightLabel];
        if (self.mPlayState == GZXPlayerStateReadyToPlay && self.is_NetWifi_play == YES && self.is_ExitPlayGround == NO && self.NetStatus == AFNetworkReachabilityStatusReachableViaWiFi){
            [self Play];
        }
    }
    else if (self.mPlayer.status == AVPlayerStatusUnknown){
        NSLog(@"AVPlayerStatusUnknown");
        [self.mProgessView setProgress:0.0 animated:NO];
        self.mPlayState = GZXPlayerStateBuffering;
        
    }
    else if (self.mPlayer.status == AVPlayerStatusFailed){
        NSLog(@"AVPlayerStatusFailed");
        self.mPlayState = GZXPlayerStateFailed;//播放失败
    }
}


#pragma mark - 监听触摸手势
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    NSLog(@"开始");
    UITouch *touch =  [touches anyObject];
    if (touch.tapCount == 1) {
        [self GetButtonShow];
    }
    
    
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    //    NSLog(@"取消");
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    //    NSLog(@"离开");
    //5秒后回调主线程
    
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    //    NSLog(@"移动");
}
#pragma mark - 出现底部View
-(void)GetButtonShow{
    if (self.mPlayFullButton.hidden == NO) {
        return;
    }
    if (self.mBottomView.hidden == YES){
        self.mBottomView.hidden = NO;
        [self performSelector:@selector(HiddenBottomView) withObject:nil afterDelay:5];
    }
    else{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(HiddenBottomView) object:nil];
        self.mBottomView.hidden = YES;
    }
}
-(void)HiddenBottomView{
    self.mBottomView.hidden = YES;
}

-(void)dealloc {
    NSLog(@"Player销毁了");
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [self.mPlayerItem xw_removeAllObserverBlocks];
    //停止网络监听
    [[AFNetworkReachabilityManager sharedManager] stopMonitoring];
}
-(void)Cancel{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(HiddenBottomView) object:nil];
    [self.mPlayerItem xw_removeAllObserverBlocks];
}


#pragma mark - 控件加载

-(void)CreatView{
    self.mActivityView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [self addSubview:self.mActivityView];
    
    
    self.mBgImageView = [[UIImageView alloc]init];
    self.mBgImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self addSubview:self.mBgImageView];
    
    self.mBottomView = [[UIView alloc] init];
    self.mBottomView.backgroundColor = [UIColor blueColor];
    self.mBottomView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    [self addSubview:self.mBottomView];
    
    
    
    self.mPlayFullButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.mPlayFullButton addTarget:self action:@selector(FullPlayAction) forControlEvents:UIControlEventTouchUpInside];
    [self.mPlayFullButton setImage:[UIImage imageNamed:@"VideoPaseImage"] forState:UIControlStateNormal];
    [self addSubview:self.mPlayFullButton];
    
    
    self.mPlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.mPlayButton addTarget:self action:@selector(playBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.mPlayButton setImage:[UIImage imageNamed:@"videoPlayBtn"] forState:UIControlStateNormal];
    [self.mPlayButton setImage:[UIImage imageNamed:@"videoPauseBtn"] forState:UIControlStateSelected];
    [self.mBottomView addSubview:self.mPlayButton];
    
    
    self.mCurrentTimeLabel = [[UILabel alloc]init];
    self.mCurrentTimeLabel.font = [UIFont systemFontOfSize:11];
    self.mCurrentTimeLabel.textColor = [UIColor whiteColor];
    self.mCurrentTimeLabel.text = @"00:00";
    self.mCurrentTimeLabel.textAlignment = NSTextAlignmentCenter;
    [self.mBottomView addSubview:self.mCurrentTimeLabel];
    
    
    
    self.mFullScreenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.mFullScreenButton addTarget:self action:@selector(fullScreenBtnCLick:) forControlEvents:UIControlEventTouchUpInside];
    [self.mFullScreenButton setImage:[UIImage imageNamed:@"kr-video-player-fullscreen"] forState:UIControlStateNormal];
    [self.mFullScreenButton setImage:[UIImage imageNamed:@"exitFullScreen"] forState:UIControlStateSelected];
    [self.mBottomView addSubview:self.mFullScreenButton];
    
    
    self.mTotalTimeLabel = [[UILabel alloc]init];
    self.mTotalTimeLabel.font = [UIFont systemFontOfSize:11];
    self.mTotalTimeLabel.textColor = [UIColor whiteColor];
    self.mTotalTimeLabel.text = @"00:00";
    self.mTotalTimeLabel.textAlignment = NSTextAlignmentCenter;
    [self.mBottomView addSubview:self.mTotalTimeLabel];
    
    
    
    self.mProgessView = [[UIProgressView alloc]init];
    self.mProgessView.progressTintColor = [UIColor whiteColor];
    self.mProgessView.trackTintColor = [UIColor grayColor];
    [self.mBottomView addSubview:self.mProgessView];
    
    
    
    
    self.mSlider = [[UISlider alloc] init];
    self.mSlider.minimumValue = 0.0;
    self.mSlider.maximumValue = 0.0;
    self.mSlider.minimumTrackTintColor = [UIColor greenColor];
    self.mSlider.maximumTrackTintColor = [UIColor clearColor];
    self.mSlider.value = 0.0;
    [self.mSlider setThumbImage:[UIImage imageNamed:@"dot"] forState:UIControlStateNormal];
    [self.mBottomView addSubview:self.mSlider];
    
    
}


-(void)CreatPalyer{
    
    self.mPlayer = [[AVPlayer alloc]init];
    if([[UIDevice currentDevice] systemVersion].floatValue >= 10.0){
        //      增加下面这行可以解决iOS10兼容性问题了
        self.mPlayer.automaticallyWaitsToMinimizeStalling = NO;
    }
    self.mPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.mPlayer];
    self.mPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.mPlayerLayer.backgroundColor = [UIColor blackColor].CGColor;
    self.mPlayerLayer = (AVPlayerLayer *)self.layer;
    [self.mPlayerLayer setPlayer:self.mPlayer];
}
-(void)setSliderEvent{
    [self.mSlider removeTarget:self action:@selector(sliderDragValueChange:) forControlEvents:UIControlEventValueChanged];
    [self.mSlider removeTarget:self action:@selector(sliderTapValueChange:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.mSlider addTarget:self action:@selector(sliderDragValueChange:) forControlEvents:UIControlEventValueChanged];
    [self.mSlider addTarget:self action:@selector(sliderTapValueChange:) forControlEvents:UIControlEventTouchUpInside];
}
#pragma mark -设置Frame
-(void)SetNorFrame{
    WKS(weakSelf);
    [self.mBgImageView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(weakSelf).with.offset(0);
        make.left.equalTo(weakSelf).with.offset(0);
        make.bottom.equalTo(weakSelf).with.offset(0);
        make.top.equalTo(weakSelf).with.offset(0);
    }];
    [self.mActivityView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(weakSelf);
    }];
    [self.mBottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(weakSelf).with.offset(0);
        make.left.equalTo(weakSelf).with.offset(0);
        make.bottom.equalTo(weakSelf).with.offset(0);
        make.height.mas_equalTo(@50);
    }];
    [self.mPlayFullButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(weakSelf);
        make.width.mas_equalTo(80);
        make.height.mas_equalTo(80);
    }];
    [self.mPlayButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.mBottomView).with.offset(0);
        make.left.equalTo(weakSelf.mBottomView).with.offset(0);
        make.bottom.equalTo(weakSelf.mBottomView).with.offset(0);
        make.width.mas_equalTo(50);
        
    }];
    [self.mCurrentTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.mBottomView).with.offset(0);
        make.left.equalTo(weakSelf.mPlayButton.mas_right).with.offset(0);
        make.bottom.equalTo(weakSelf.mBottomView).with.offset(0);
        make.width.mas_equalTo(60);
    }];
    [self.mFullScreenButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.mBottomView).with.offset(0);
        make.right.equalTo(weakSelf.mBottomView).with.offset(0);
        make.bottom.equalTo(weakSelf.mBottomView).with.offset(0);
        make.width.mas_equalTo(50);
    }];
    [self.mTotalTimeLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.mBottomView).with.offset(0);
        make.right.equalTo(weakSelf.mFullScreenButton.mas_left).with.offset(0);
        make.bottom.equalTo(weakSelf.mBottomView).with.offset(0);
        make.width.mas_equalTo(60);
    }];
    [self.mProgessView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(weakSelf.mCurrentTimeLabel.mas_right).with.offset(0);
        make.right.equalTo(weakSelf.mTotalTimeLabel.mas_left).with.offset(0);
        make.top.equalTo(weakSelf.mTotalTimeLabel.mas_centerY).with.offset(0.5);
        make.height.mas_equalTo(1);
    }];
    
    [self.mSlider mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(weakSelf.mCurrentTimeLabel.mas_right).with.offset(0);
        make.right.equalTo(weakSelf.mTotalTimeLabel.mas_left).with.offset(0);
        make.top.equalTo(weakSelf.mTotalTimeLabel.mas_centerY).with.offset(-15);
        make.height.mas_equalTo(30);
    }];
    
    [self layoutIfNeeded];
    
}
#pragma mark - 弹框处理
-(void)ShowAlertView:(NSString *)title{
    __weak typeof(self)weakSelf = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        weakSelf.is_Net4G_Play = NO;
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        weakSelf.is_Net4G_Play = YES;
        if (weakSelf.mPlayerItem) {
            [weakSelf.mPlayerItem xw_removeObserverBlockForKeyPath:@"loadedTimeRanges"];
            [weakSelf.mPlayerItem xw_addObserverBlockForKeyPath:@"loadedTimeRanges" block:^(id  _Nonnull obj, id  _Nonnull oldVal, id  _Nonnull newVal) {
                [weakSelf SetLoadTimeRanges];
            }];
            [weakSelf Play];
        }
    }]];
    
    [self.rootCtrl presentViewController:alertController animated:YES completion:nil];
}

#pragma mark  - 横竖屏切换
- (void)deviceOrientationDidChange{
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if (orientation == UIDeviceOrientationPortrait || orientation == UIDeviceOrientationPortraitUpsideDown) {
        [self changeRotate:UIDeviceOrientationPortrait];
    }
    else if (orientation == UIDeviceOrientationLandscapeLeft){
        [self changeRotate:UIDeviceOrientationLandscapeLeft];
    }
    else if (orientation == UIDeviceOrientationLandscapeRight){
        [self changeRotate:UIDeviceOrientationLandscapeRight];
    }
}
#pragma mark -横竖屏切换
- (void)changeRotate:(UIDeviceOrientation)interfaceOrientation{
    
    if (interfaceOrientation == UIDeviceOrientationPortrait
        || interfaceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        [self toSmallScreen];
    } else {
        [self toFullScreenWithInterfaceOrientation:interfaceOrientation];
    }
}
///横屏
-(void)toFullScreenWithInterfaceOrientation:(UIDeviceOrientation)interfaceOrientation{
    
    WKS(weakSelf);
    [self mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.mFatherView).with.offset(0);
        make.right.equalTo(weakSelf.mFatherView).with.offset(0);
        make.left.equalTo(weakSelf.mFatherView).with.offset(0);
        make.height.mas_equalTo(kScreenHeight);
    }];
    
    [weakSelf setNeedsUpdateConstraints];
    [weakSelf updateConstraintsIfNeeded];
    [UIView animateWithDuration:0.1 animations:^{
        [weakSelf layoutIfNeeded];
        weakSelf.isFullScreen = YES;
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
        
    }];
    
}
///竖屏
-(void)toSmallScreen{
    WKS(weakSelf);
    [self mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.mFatherView).with.offset(0);
        make.right.equalTo(weakSelf.mFatherView).with.offset(0);
        make.left.equalTo(weakSelf.mFatherView).with.offset(0);
        make.height.mas_equalTo(weakSelf.mSmallFrame.size.height);
    }];
    [weakSelf setNeedsUpdateConstraints];
    [weakSelf updateConstraintsIfNeeded];
    [UIView animateWithDuration:0.1 animations:^{
        [weakSelf layoutIfNeeded];
        weakSelf.isFullScreen = NO;
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    }];
}


#pragma mark - 设置最初的slider
-(void)SetRrightLabel{
    
    CGFloat current = CMTimeGetSeconds(self.mPlayerItem.asset.duration);
    if (!isnan(current)) {
        NSInteger proSec = (NSInteger)current % 60;
        NSInteger proMin = (NSInteger)current / 60;
        self.mTotalTimeLabel.text = [NSString stringWithFormat:@"%02zd:%02zd", proMin, proSec];
        self.mSlider.maximumValue = current;
    }
    
}

#pragma mark - 设置默认图片

-(void)setMDefImageString:(NSString *)mDefImageString{
    _mDefImageString = mDefImageString;
    
//    [self.mBgImageView sd_setImageWithURL:[NSURL URLWithString:mDefImageString]];
}


@end
