//
//  JZListenVoiceManager.m
//
//  Created by Jesse on 2021/7/15.
//

#import "JZListenVoiceManager.h"

@interface JZListenVoiceManager ()

@property (nonatomic, assign) NSInteger currentTime; //当前时间
@property (nonatomic, strong) id timeObserver;       //播放监听
@property (nonatomic, assign) BOOL hasKVO;           //是否有监听

@end

@implementation JZListenVoiceManager

- (void)dealloc {
    if (_timeObserver) {
        [_player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.hasKVO) {
        [_player removeObserver:self forKeyPath:@"status"];
        _player = nil;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)playItemURL {
    self = [super init];
    if (self) {
        [self initPlayerWithItemURL:playItemURL];
    }
    return self;
}

- (void)initPlayerWithItemURL:(NSURL *)playUrl {
    if (!playUrl) {
        //JZ_shop_listenVoice_url_empty @{@"voiceUrl" : playUrl.absoluteString.length > 0 ? playUrl.absoluteString : @"listenUrlEmpty"}
        return;
    }
    [self clearInfo];
    
    //后台 && 静音模式下 能播放
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:playUrl];
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    
    //初始化总时长
    AVAsset *asset = playerItem.asset;
    CMTime duration = asset.duration;
    NSTimeInterval totalDuration = (NSTimeInterval)CMTimeGetSeconds(duration);
    self.totalTime = totalDuration;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didPlayToEnd) name:AVPlayerItemDidPlayToEndTimeNotification object:[self.player currentItem]];
    //监听status属性
    [self.player addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    self.hasKVO = YES;
}

- (void)clearInfo {
    if (self.hasKVO) {
        self.hasKVO = NO;
        [self pause];
        if (self.timeObserver) {
            [self.player removeTimeObserver:self.timeObserver];
            self.timeObserver = nil;
        }
        [self.player removeObserver:self forKeyPath:@"status"];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

//播放完成
- (void)didPlayToEnd {
    if (self.delegate && [self.delegate respondsToSelector:@selector(JZAVPlayStatusChange:message:)]) {
        [self.delegate JZAVPlayStatusChange:JZAVPlayStatus_end message:@"播放完成"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if (object == self.player && [keyPath isEqualToString:@"status"]) {
        if (self.player.status == AVPlayerStatusFailed) {
            //AVPlayer Failed
            
        } else if (self.player.status == AVPlayerStatusReadyToPlay) {
            //AVPlayerStatusReadyToPlay
            if (self.delegate && [self.delegate respondsToSelector:@selector(JZAVPlayStatusChange:message:)]) {
                [self.delegate JZAVPlayStatusChange:JZAVPlayStatus_readyToPlay message:@"准备播放"];
            }
            [self addPeriodicTimeObserver];
            
        } else if (self.player.status == AVPlayerItemStatusUnknown) {
            //AVPlayer Unknown
            
        }
    }
}

#pragma mark 监听播放进度
- (void)addPeriodicTimeObserver {
    @weakify(self);
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        @strongify(self);
        //计算当前在第几秒
        NSInteger currentTime = (NSInteger)CMTimeGetSeconds(time);
        //避免重复调用
        if (currentTime == self.currentTime) {
            return;
        }
        self.currentTime = currentTime;
        if ([self.delegate respondsToSelector:@selector(JZAVPlayWithCurrentTime:)]) {
            [self.delegate JZAVPlayWithCurrentTime:CMTimeGetSeconds(time)];
        }
    }];
}

#pragma mark - 时间转化成字符串
- (NSString *)intervalTimeToString:(NSTimeInterval)timeInterval {
    //”1秒内时长计算问题“展示显示兼容
    //比如资源3.02秒，有时资源加载时长会是2.8秒=2秒，此时播放3秒后最后一秒会显示-1，需要兼容显示
    NSTimeInterval putInterval = timeInterval > 0 ? timeInterval : 0;
    
    NSInteger minute = (NSInteger)putInterval / 60;
    NSInteger second = (NSInteger)putInterval % 60;
    if (minute >= 60) {
        NSInteger hour = minute / 60;
        minute = minute % 60;
        minute += hour * 60;
    }
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minute, (long)second];
}

#pragma mark - Properties
- (AVPlayer *)player {
    if (!_player) {
        _player = [[AVPlayer alloc] init];
    }
    return _player;
}

#pragma mark - 开始播放
- (void)play {
    //如果在停止播放状态就播放
    if (self.player.rate == 0) {
        [self.player play];
    }
}

#pragma mark 暂停播放
- (void)pause {
    //如果在播放状态就停止
    if (self.player.rate == 1) {
        [self.player pause];
        [self seekToTime:self.currentTime block:^(BOOL finish) {}];
    }
}

#pragma mark 停止播放
- (void)stop {
    //暂停
    [self pause];
    //到0
    [self seekToTime:0 block:^(BOOL finish) {}];
}

#pragma mark 跳转多少秒
- (void)seekToTime:(NSTimeInterval)time block:(void (^)(BOOL))block{
    //向下取整
    time = (int)time;
    
    time = MAX(0, time);
    time = MIN(time, self.totalTime);
    
    //设置时间
    CMTime changedTime = CMTimeMakeWithSeconds(time, 1);
    [self.player seekToTime:changedTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:block];
}

@end
