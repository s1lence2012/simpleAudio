//
//  JZVisitRecordPlayView.m
//
//  Created by Jesse on 2023/4/28.
//

#import "JZVisitRecordPlayView.h"
#import <JZMediaModule/JZListenVoiceManager.h>

@import Masonry;

static const NSInteger kBGViewHeight = 42;
NSString * const JZRecordPlayerReceiveDeleteMessageNotification = @"JZRecordPlayerReceiveDeleteMessageNotification";
NSString * const JZRecordPlayerReceivePlayMessageNotification = @"JZRecordPlayerReceivePlayMessageNotification";
NSString * const JZRecordPlayerReceiveUrlPath = @"urlPath";

@interface JZVisitRecordPlayView ()<JZListenVoiceManagerDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) JZListenVoiceManager *voiceManager;

//ui
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIButton *playBtn;       //播放按钮
@property (nonatomic, strong) UISlider *slider;        //时间进度条
@property (nonatomic, strong) UILabel *totalTimeLabel; //剩余总时间

//data
@property (nonatomic, strong) NSMutableArray *listenedDetailArr;//已听时间 单位(秒）
@property (nonatomic, strong) NSMutableArray *listenedDetailUpsertedArr;//已听时间(已上传成功) 单位(秒）
//log
@property (nonatomic, copy) NSString *startTime;
@end

@implementation JZVisitRecordPlayView

- (void)removeFromSuperview {
    [super removeFromSuperview];
    [self logLeaveListen];
    //清除信息
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        
    } else {
        if (self.voiceManager.player.rate == 1) {
            //如果是播放状态 离开页面 前上传服务一次，否则重复上传没必要
            [self upsertListenRecordRequest];
            //停止埋点 - 3.退出页面
            [self logStopListenVoice];
            //UI
            [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
            //暂停
            [self.voiceManager pause];
        }
    }
}

- (void)logLeaveListen {
    //LOG
//    [[JZUTTracker instance] trackClickWithElementId:@"JZ_listenVoice_leave"
//                                        properties:@{ @"recordTotalTime": @(self.voiceManager.totalTime),
//                                                      @"recordListenedTime" : @(self.listenedDetailArr.count),
//                                                      @"recordingId": self.recordingId.stringValue ?: @"",
//                                                      @"recordUrl" : self.recordUrl.absoluteString ?: @"",
//                                                      @"needUpload" :  @(self.needUpload)
//                                                   }];
}

#pragma mark - NotificationCenter
- (void)applicationWillTerminate {
    if (self.voiceManager.player.rate == 1) {
        //停止埋点 - 1.exit app
        [self logStopListenVoice];
    }
}

- (void)receiveDeleteMessageAction:(NSNotification *)notify {
    NSString *receiveFilePath = notify.userInfo[JZRecordPlayerReceiveUrlPath] ?: @"";
    if (receiveFilePath.length > 0 && [receiveFilePath isEqualToString:self.recordUrl.path]) {
        if (self.voiceManager.player.rate == 1) {
            //UI
            [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
            //停止
            [self.voiceManager stop];
            //播放结束时 上传服务
            [self upsertListenRecordRequest];
            //停止埋点
            [self logStopListenVoice];
        }
    }
}

- (void)receivePlayMessageAction:(NSNotification *)notify {
    NSString *receiveFilePath = notify.userInfo[JZRecordPlayerReceiveUrlPath] ?: @"";
    if (receiveFilePath.length > 0 && self.recordUrl.path.length > 0 && ![receiveFilePath isEqualToString:self.recordUrl.path]) {
        if (self.voiceManager.player.rate == 1) {
            //UI
            [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
            //暂停
            [self.voiceManager pause];
            //播放结束时 上传服务
            [self upsertListenRecordRequest];
            //暂停埋点
            [self logPauseListenVoice];
        }
    }
}

#pragma mark - initail
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.listenedDetailArr = [NSMutableArray array];
        self.listenedDetailUpsertedArr = [NSMutableArray array];
        [self initViews];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivePlayMessageAction:) name:JZRecordPlayerReceivePlayMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveDeleteMessageAction:) name:JZRecordPlayerReceiveDeleteMessageNotification object:nil];
    }
    return self;
}

- (void)initViews {
    [self addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self);
        make.height.mas_equalTo(@(kBGViewHeight));
    }];
    
    [self.contentView addSubview:self.playBtn];
    [self.contentView addSubview:self.slider];
    [self.contentView addSubview:self.totalTimeLabel];
    
    [self.playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.contentView);
        make.left.equalTo(self.contentView).offset(10);
        make.size.mas_equalTo(CGSizeMake(24, 24));
    }];
    [self.slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.playBtn.mas_right).offset(12);
        make.right.equalTo(self.contentView).offset(-52);
        make.centerY.equalTo(self.playBtn);
        make.height.mas_equalTo(20);
    }];
    [self.totalTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView.mas_right).offset(-12);
        make.centerY.equalTo(self.playBtn);
        make.size.mas_equalTo(CGSizeMake(34, 20));
    }];
}

#pragma mark - 设置录音地址 并初始化
- (void)setRecordUrl:(NSURL *)recordUrl {
    _recordUrl = recordUrl;
    [self initVoiceManager];
}

- (void)initVoiceManager {
    self.voiceManager = [[JZListenVoiceManager alloc] initWithURL:self.recordUrl];
    self.voiceManager.delegate = self;
    //设置总时长
    self.totalTimeLabel.text = [self.voiceManager intervalTimeToString:self.duration.doubleValue > 0 ? self.duration.doubleValue : self.voiceManager.totalTime];
}

#pragma mark - requests
#pragma mark 上传服务
- (void)upsertListenRecordRequest {
    if (!self.needUpload) {
        return;
    }
    
    if (self.recordingId && self.listenedDetailArr.count > 0 && ![self.listenedDetailUpsertedArr isEqualToArray:self.listenedDetailArr]) {
        @weakify(self);
        [self reqCustomUpdateRecordingListenWithId:self.recordingId withListenDetail:self.listenedDetailArr success:^{
            @strongify(self);
            self.listenedDetailUpsertedArr = [NSMutableArray arrayWithArray:self.listenedDetailArr];
        } failure:^{
            //服务没返回 不做处理
        }];
    }
}

- (void)reqCustomUpdateRecordingListenWithId:(NSNumber *)recordingId
                            withListenDetail:(NSArray *)listenDetail
                                     success:(void(^)(void))success
                                     failure:(void(^)(void))failure {
    NSDictionary *parameters = [self bizParameters];
    NSString *method = [parameters JZ_stringForKey:@"method"];
    NSString *service = [parameters JZ_stringForKey:@"service"];
    NSString *module = [parameters JZ_stringForKey:@"module"];
    
    //reqParams
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    if (recordingId) {
        [dic setValue:recordingId forKey:@"recordingId"];
    }
    if (listenDetail) {
        [dic setValue:listenDetail forKey:@"listenDetail"];
    }

    DRDBaseAPI *api = [[JZHybridSNApi alloc] initWithParameters:@{@"request": dic} requestMethod:method apiService:service apiModel:module];
    [api setApiCompletionHandler:^(id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            if (failure) {
                failure();
            }
        } else {
            if (success) {
                success();
            }
        }
    }];
    [api start];
}

//读取服务配置 (默认走拜访上传服务)
- (NSDictionary *)bizParameters {
    if ([self.uploadServiceParameters allKeys].count == 0) {
        //default service config
        return @{@"method" : @"updateRecordingListen",
                 @"service" : @"voiceService",
                 @"module" : @"JZ-siri"};
    }
    return self.uploadServiceParameters.copy;
}

#pragma mark - JZListenVoiceManagerDelegate
- (void)JZAVPlayStatusChange:(JZAVPlayStatus)status message:(NSString *)message {
    switch (status) {
        case JZAVPlayStatus_readyToPlay://初始化 - 准备播放（总时长）
        {
            NSTimeInterval current = CMTimeGetSeconds([self.voiceManager.player.currentItem currentTime]);
            [self updateCurrentTimeLabel:current totalTimeLabel:self.voiceManager.totalTime];
            [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
        }
            break;
        case JZAVPlayStatus_end:
        {
            [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
            [self.voiceManager stop];
            //播放结束时 上传服务
            [self upsertListenRecordRequest];
            
            //停止埋点 2.正常播放完
            [self logStopListenVoice];
        }
            break;
        default:
            break;
    }
}

- (void)JZAVPlayWithCurrentTime:(NSInteger)currentTime {
    [self updateCurrentTimeLabel:currentTime totalTimeLabel:self.voiceManager.totalTime];
    if (![self.listenedDetailArr containsObject:@(currentTime)] && currentTime > 0) {
        [self.listenedDetailArr addObject:@(currentTime)];
    }
    
    if (self.listenedDetailArr.count % 5 == 0) {
        //播放过程中, 数量是5的倍数时(跟pc端、安卓逻辑保持一致) 上传服务
        [self upsertListenRecordRequest];
    }
}


#pragma mark - actions
#pragma mark 播放/暂停
- (void)playBtnAction {
    if (self.voiceManager.player.rate == 1) {
        [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
        [self.voiceManager pause];
        
        //暂停时 上传服务
        [self upsertListenRecordRequest];
        
        //暂停埋点 1.正常点暂停
        [self logPauseListenVoice];
    } else {
        [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_pause"] forState:UIControlStateNormal];
        [self.voiceManager play];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:JZRecordPlayerReceivePlayMessageNotification object:nil userInfo:@{JZRecordPlayerReceiveUrlPath : self.recordUrl.path ?: @""}];
        
        //播放时间重置
        self.startTime = [self returnCurrentTime];
        
        //播放埋点
        [self logPlayListenVoice];
    }
}

#pragma mark 外部控制暂停
- (void)pausePlay {
    if (self.voiceManager.player.rate == 1) {
        [self.playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
        [self.voiceManager pause];      //暂停播放器
    }
}

#pragma mark 开始拖动
- (void)sliderTouchDownAction:(UISlider *)slider {
    
}

#pragma mark 拖动离开
- (void)sliderTouchUpInsideAction:(UISlider *)slider {
    //离开进行跳转
    [self.voiceManager seekToTime:slider.value * self.voiceManager.totalTime
                            block:^(BOOL finish) {
    }];
}

#pragma mark 拖动过程
- (void)sliderValueChangeAction:(UISlider *)slider {
    [self updateCurrentTimeLabel:(slider.value * self.voiceManager.totalTime) totalTimeLabel:self.voiceManager.totalTime];
}

#pragma mark - 设置开始时间文本 总时间文本展示
- (void)updateCurrentTimeLabel:(NSTimeInterval)currentTime totalTimeLabel:(NSTimeInterval)duration {
    self.totalTimeLabel.text = [self.voiceManager intervalTimeToString:duration - currentTime];
    [self.slider setValue:currentTime/duration animated:NO];
}

#pragma mark - 埋点 (播放、暂停、停止)
- (void)logPlayListenVoice {
//    [[JZUTTracker instance] trackClickWithPageName:@""
//                                         elementId:@"JZ_listenVoice_play"
//                                        properties:@{@"recordingId": self.recordingId.stringValue ?: @"",
//                                                     @"needUpload" :  @(self.needUpload)}];
}

- (void)logPauseListenVoice {
    //暂停埋点 - 1.正常点暂停 2.进入后台(当在播放时)
//    [[JZUTTracker instance] trackClickWithPageName:@""
//                                         elementId:@"JZ_listenVoice_pause"
//                                        properties:@{ @"playTimeStamp": self.startTime ?: @"",
//                                                      @"pauseTimeStamp" : [self returnCurrentTime],
//                                                      @"recordingId": self.recordingId.stringValue ?: @"",
//                                                      @"recordUrl" : self.recordUrl.absoluteString ?: @"",
//                                                      @"needUpload" :  @(self.needUpload)
//                                                   }];
}

- (void)logStopListenVoice {
    //停止埋点 - 1.exit app 2.正常播放完 3.退出页面
//    [[JZUTTracker instance] trackClickWithPageName:@""
//                                         elementId:@"JZ_listenVoice_stop"
//                                        properties:@{ @"playTimeStamp": self.startTime ?: @"",
//                                                      @"stopTimeStamp" : [self returnCurrentTime],
//                                                      @"recordingId": self.recordingId.stringValue ?: @"",
//                                                      @"recordUrl" : self.recordUrl.absoluteString ?: @"",
//                                                      @"needUpload" :  @(self.needUpload)
//                                                   }];
}

- (NSString *)returnCurrentTime {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    NSString *time = [formatter stringFromDate:[NSDate date]];
    return time ?: @"";
}

#pragma mark - properties
- (UIView *)contentView {
    if (!_contentView) {
        _contentView = [UIView new];
        _contentView.backgroundColor = [UIColor colorWithHex:0xF7F9FC];
    }
    return _contentView;
}

- (UIButton *)playBtn {
    if (!_playBtn) {
        _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_playBtn setImageEdgeInsets:UIEdgeInsetsMake(1.5, 1.5, 1.5, 1.5)];
        [_playBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_play"] forState:UIControlStateNormal];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playBtnAction)];
        [_playBtn addGestureRecognizer:tap];
    }
    return _playBtn;
}

- (void)panGestureAction:(UIPanGestureRecognizer *)recognizer {
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            break;
        }
        case UIGestureRecognizerStateChanged: {
            break;
        }
        case UIGestureRecognizerStateEnded: {
            CGPoint locationPoint = [recognizer locationInView:self.slider];
            float slidervalue = fabs(locationPoint.x - self.slider.origin.x)/self.slider.frame.size.width;
            [self.voiceManager seekToTime:slidervalue * self.voiceManager.totalTime
                                    block:^(BOOL finish) {
            }];
            break;
        }
        case UIGestureRecognizerStateCancelled:
            break;
            
        case UIGestureRecognizerStateFailed:
            break;
        default:
            break;
    }
}

- (UISlider *)slider {
    if (!_slider) {
        _slider = [[UISlider alloc] init];
        [_slider setThumbImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_record_move"] forState:UIControlStateNormal];
        _slider.minimumTrackTintColor = [UIColor colorWithHex:0xFA6323];
        _slider.maximumTrackTintColor = [UIColor colorWithHex:0xE4E7ED];
        
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureAction:)];
        panGesture.delegate = self;
        [_slider addGestureRecognizer:panGesture];
    }
    return _slider;
}

- (UILabel *)totalTimeLabel {
    if (!_totalTimeLabel) {
        _totalTimeLabel = [UILabel new];
        _totalTimeLabel.font = [UIFont fontWithName:MEDIUMFONTNAME size:12];
        _totalTimeLabel.textAlignment = NSTextAlignmentCenter;
        _totalTimeLabel.textColor = [UIColor colorWithHex:0xFA6323];
    }
    return _totalTimeLabel;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
