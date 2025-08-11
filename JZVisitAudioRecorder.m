//
//  JZVisitAudioRecorder.m
//  JZShopModule
//
//  Created by Jesse on 2023/4/24.
//

#import "JZVisitAudioRecorder.h"
#import <JZLogModule/JZLogModule.h>
@import JZUIKit;

#define ERROR_AUDIO_DOMAIN @"Audio_Domain_Error"
#define JZ_Audio_RECORD_DIR @"JZVisitRecord"

@interface JZVisitAudioRecorder ()

@property (nonatomic, copy) NSString *audioPath;
@property (nonatomic, copy) NSString *rootPath;
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, copy) NSString *previousCategory;
@property (nonatomic, copy) __nullable JZVisitAudioRecordChangeStatusBlock stopStatusBlock;
//log
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval timeout; //不传或者传0，就认为无限时长

@end

@implementation JZVisitAudioRecorder
+ (JZVisitAudioRecorder *)shareAudioRecorder {
    static dispatch_once_t once;
    static JZVisitAudioRecorder *JZAudioRecord = nil;
    dispatch_once(&once, ^{
        JZAudioRecord = [[self alloc] init];
    });
    return JZAudioRecord;
}

- (id)init {
    self = [super init];
    if (self) {
        self.audioSession = [AVAudioSession sharedInstance];
        self.timeout = 0;
    }
    return self;
}

#pragma mark - 初始化录音可用性
- (void)checkAvailabilityWithCallback:(void (^)(NSError *error))callback {
    if (!callback) return;
    
    [self requestRecordPermission:^(AVAudioSessionRecordPermission recordPermission) {
        //第一步：拥有访问麦克风的权限
        if (recordPermission == AVAudioSessionRecordPermissionDenied){
            NSError *error = [NSError errorWithDomain:ERROR_AUDIO_DOMAIN
                                                 code:JZVisitAudioRecordOperateTypeAuthorizationDenied
                                             userInfo:@{@"msg": @"未开启录音权限"}];
            callback(error);
            return;
        }
        //第二步：当前麦克风未使用
        if (self.isRecording) {
            NSError *error = [NSError errorWithDomain:ERROR_AUDIO_DOMAIN
                                                 code:JZVisitAudioRecordOperateTypeMultiRequest
                                             userInfo:@{@"msg": @"麦克风正在使用"}];
            
            callback(error);
            return;
        }
        //第三步：设置AudioSession.category
        self.previousCategory = self.audioSession.category;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:self.audioSession];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:self.audioSession];
        NSError *error;
        BOOL success = [self.audioSession
                        setCategory:AVAudioSessionCategoryRecord
                        withOptions:AVAudioSessionCategoryOptionDuckOthers
                        error:&error];
        
        if (!success || error) {
            callback([NSError errorWithDomain:ERROR_AUDIO_DOMAIN
                                         code:JZVisitAudioRecordOperateTypeInitFailed
                                     userInfo:@{@"msg": @"录音初始化失败"}]);
            return;
        }
        //第四步：激活AudioSession
        error = nil;
        success = [self.audioSession setActive:YES error:&error];
        if (!success || error) {
            callback([NSError errorWithDomain:ERROR_AUDIO_DOMAIN
                                         code:JZVisitAudioRecordOperateTypeCreateAudioFileFailed
                                     userInfo:@{@"msg": @"录音文件创建失败"}]);
            return;
        }
        //第五步：创建临时录音文件
        NSURL *audioRecordingUrl = [NSURL fileURLWithPath:[self audioRecordingPath]];
        if (!audioRecordingUrl) {
            callback([NSError errorWithDomain:ERROR_AUDIO_DOMAIN
                                         code:JZVisitAudioRecordOperateTypeCreateAudioFileFailed
                                     userInfo:@{@"msg": @"录音文件创建失败"}]);
            return;
        }
        //第六步：创建AVAudioRecorder
        error = nil;
        self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:audioRecordingUrl
                                                         settings:self.recordingSettings
                                                            error:&error];
        
        if (!self.audioRecorder || error) {
            self.audioRecorder = nil;
            callback([NSError errorWithDomain:ERROR_AUDIO_DOMAIN
                                         code:JZVisitAudioRecordOperateTypeInitFailed
                                     userInfo:@{@"msg": @"录音初始化失败"}]);
            return;
        }
        
        //第七步：开始录音
        if (self.timeout > 0) {
            success = [self.audioRecorder recordForDuration:self.timeout];
        } else {
            success = [self.audioRecorder record];
        }
        if (!success) {
            self.audioRecorder = nil;
            callback([NSError errorWithDomain:ERROR_AUDIO_DOMAIN
                                         code:JZVisitAudioRecordOperateTypeRecordError
                                     userInfo:@{@"msg": @"录制失败"}]);
            return;
        }
        callback(nil);
    }];
}

#pragma mark 系统鉴权
- (void)requestRecordPermission:(void (^)(AVAudioSessionRecordPermission recordPermission))callback {
    AVAuthorizationStatus author = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    
    if (author == AVAuthorizationStatusAuthorized) {
        callback(AVAudioSessionRecordPermissionGranted);
    } else if (author == AVAuthorizationStatusRestricted || author == AVAuthorizationStatusDenied) {
        //无权限
        callback(AVAudioSessionRecordPermissionDenied);
    } else if (author == AVAuthorizationStatusNotDetermined) {
        if ([self.audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
            [self.audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
                
            }];
        }
        callback(AVAudioSessionRecordPermissionDenied);
    }
}

#pragma mark - 开始录音
- (void)startRecordWithRootPath:(NSString *)rootPath timeout:(NSTimeInterval)timeout block:(JZVisitAudioRecordChangeStatusBlock)block {
    if (self.isRecording) {
        return;
    }
    self.rootPath = rootPath;
    self.timeout = timeout;
    @weakify(self);
    [self checkAvailabilityWithCallback:^(NSError *error) {
        @strongify(self);
        if (!error) {
            self.isRecording = YES;
            self.audioRecorder.delegate = self;
            //开启仪表计数功能, 可以获取当前录音音量大小
            self.audioRecorder.meteringEnabled = YES;
            self.startTime = [[NSDate date] timeIntervalSince1970];
            
            if (block) {
                block(YES, JZVisitAudioRecordOperateTypePlaySuccess, @"录音成功");
            }
            
            [JZLogManager logRemoteCustom:@"media"
                               metricName:@"start_audio_recorder_success" fileds:@{@"status":@(1)}
                                     tags:nil extras:@{}];
        } else {
            if (block) {
                block(NO, error.code, [error.userInfo objectForKey:@"msg"] ?: @"录音失败");
            }
            
            [JZLogManager logRemoteCustom:@"media" metricName:@"start_audio_recorder_fail"
                                   fileds:@{@"status":@(0)}
                                     tags:nil extras:@{@"error": [error.userInfo objectForKey:@"msg"] ?: @"录音失败",
                                                       @"code" : @(error.code),
                                                     }];
        }
    }];
}

#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    [self didStopRecord];
}

#pragma mark - 停止
- (void)stopRecord {
    [self stopRecordWithBlock:nil];
}

- (void)stopRecordWithBlock:(__nullable JZVisitAudioRecordChangeStatusBlock)stopBlock {
    self.stopStatusBlock = stopBlock;
    if (self.audioRecorder.isRecording) {
        [self.audioRecorder stop];
    }
    self.isRecording = NO;
    
    NSTimeInterval timeNow = [[NSDate date] timeIntervalSince1970];
    NSString *duration = [NSString stringWithFormat:@"%.2f", timeNow - self.startTime];
    [JZLogManager logRemoteCustom:@"media"
                       metricName:@"stop_audio_recorder" fileds:@{@"status":@(1)}
                             tags:nil extras:@{@"fileDuration": duration,
                                               @"rootPath" : self.rootPath ?: @"unknown"
                                             }];
}

- (void)didStopRecord {
    if (self.stopStatusBlock) {
        self.stopStatusBlock(YES, JZVisitAudioRecordOperateTypeStopSuccess, @"停止录音成功");
        self.stopStatusBlock = nil;
    }
    self.audioPath = nil;
    self.audioRecorder.delegate = nil;
    self.audioRecorder = nil;
    if (self.previousCategory.length > 0) {
        [self.audioSession setCategory:self.previousCategory error:nil];
        self.previousCategory = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)getIsRecordingStatusWithBlock:(JZVisitAudioRecorderStatusBlock)block {
    if (block) {
        if (self.audioRecorder) {
            NSTimeInterval timeNow = [[NSDate date] timeIntervalSince1970];
            NSString *duration = [NSString stringWithFormat:@"%.0f", timeNow - self.startTime];
            
            block(self.audioRecorder.isRecording, duration.doubleValue, self.timeout);
        } else {
            block(NO, 0, 0);
        }
    }
}

#pragma mark - 获取aac音频文件列表
- (NSArray <NSString *>*)returnFilesInRootPath:(NSString *)rootPath {
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", JZ_Audio_RECORD_DIR, rootPath]];
    //获得当前文件的所有子文件subpathsAtPath
    NSArray *pathlList = [[NSFileManager defaultManager] subpathsAtPath:path];
    
    NSArray *sortedPaths = [pathlList sortedArrayUsingComparator:^(NSString * firstPath, NSString* secondPath) {
        NSString *firstUrl = [path stringByAppendingPathComponent:firstPath];//获取前一个文件完整路径
        NSString *secondUrl = [path stringByAppendingPathComponent:secondPath];//获取后一个文件完整路径
        NSDictionary *firstFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:firstUrl error:nil];//获取前一个文件信息
        NSDictionary *secondFileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:secondUrl error:nil];//获取后一个文件信息
        id firstData = [firstFileInfo objectForKey:NSFileCreationDate];//获取前一个文件修改时间
        id secondData = [secondFileInfo objectForKey:NSFileCreationDate];//获取后一个文件修改时间
        return [firstData compare:secondData];//降序
    }];
    
    //需要只获得录音文件
    NSMutableArray *audioPathList = [NSMutableArray array];
    //遍历所有这个文件夹下的子文件
    for (NSString *audioPath in sortedPaths) {
        //通过对比文件的延展名（扩展名 尾缀） 来区分是不是录音文件
        if ([audioPath.pathExtension isEqualToString:@"aac"]) {
            //把筛选出来的文件放到数组中
            [audioPathList addObject:[path stringByAppendingFormat:@"/%@", audioPath]];
        }
    }
    
    return audioPathList ?: @[];
}

#pragma mark - 删除
- (void)removeCurrentFilePath:(NSString *)path removeBlock:(JZVisitAudioRecorderRemoveBlock)removeBlock {
    if (path.length == 0) {
        if (removeBlock) {
            removeBlock(NO, JZVisitAudioRecordRemoveDirStatusParamError, @"文件路径为空");
        }
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError *err = nil;
        BOOL deleteResult = [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
        if (removeBlock) {
            removeBlock(deleteResult, deleteResult ? JZVisitAudioRecordRemoveDirStatusSuccess : JZVisitAudioRecordRemoveDirStatusFail, err.localizedDescription ?: @"");
        }
    } else {
        if (removeBlock) {
            removeBlock(NO, JZVisitAudioRecordRemoveDirStatusWithoutDir, @"无此目录文件夹");
        }
    }
}

- (void)removeCurrentRootPathDirFiles:(NSString *)rootPath removeBlock:(JZVisitAudioRecorderRemoveBlock)removeBlock {
    if (rootPath.length == 0) {
        if (removeBlock) {
            removeBlock(NO, JZVisitAudioRecordRemoveDirStatusParamError, @"文件路径为空");
        }
        return;
    }
    
    NSString *dirName = [NSString stringWithFormat:@"%@/%@", JZ_Audio_RECORD_DIR, rootPath];
    NSString *removePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:dirName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:removePath]) {
        NSError *err = nil;
        BOOL deleteResult = [[NSFileManager defaultManager] removeItemAtPath:removePath error:&err];
        if (removeBlock) {
            removeBlock(deleteResult, deleteResult ? JZVisitAudioRecordRemoveDirStatusSuccess : JZVisitAudioRecordRemoveDirStatusFail, err.localizedDescription ?: @"");
        }
    } else {
        if (removeBlock) {
            removeBlock(NO, JZVisitAudioRecordRemoveDirStatusWithoutDir, @"无此目录文件夹");
        }
    }
}

- (void)removeAllAudioRecordFilesBlock:(JZVisitAudioRecorderRemoveBlock)block {
    NSString *removePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:JZ_Audio_RECORD_DIR];
    if ([[NSFileManager defaultManager] fileExistsAtPath:removePath]) {
        NSError *err = nil;
        BOOL deleteResult = [[NSFileManager defaultManager] removeItemAtPath:removePath error:&err];
        if (block) {
            block(deleteResult, deleteResult ? JZVisitAudioRecordRemoveDirStatusSuccess : JZVisitAudioRecordRemoveDirStatusFail, err.localizedDescription ?: @"");
        }
    } else {
        if (block) {
            block(NO, JZVisitAudioRecordRemoveDirStatusWithoutDir, @"无此目录文件夹");
        }
    }
}

#pragma mark - Notification Action
//被打断
- (void)handleInterruption:(NSNotification*)notification {
    NSDictionary *info = notification.userInfo;
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        [self stopRecord];
        
        [JZLogManager logRemoteCustom:@"media"
                           metricName:@"audio_recorder_handleInterruption" fileds:@{@"status":@(1)}
                                 tags:nil extras:@{}];
        
    } else {
        AVAudioSessionInterruptionOptions options = [info[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (options == AVAudioSessionInterruptionOptionShouldResume) {
            //Handle Resume
        }
    }
}

- (void)audioSessionRouteChange:(NSNotification*)notification {
    NSDictionary *info = notification.userInfo;
    AVAudioSessionRouteChangeReason reason = [info[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason == AVAudioSessionRouteChangeReasonCategoryChange) {
        if ([self.audioSession.category isEqualToString:AVAudioSessionCategoryRecord] || [self.audioSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]){
            //不处理
            
        } else {
            [self stopRecord];
        }
    }
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *previouRoute = info[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *previousputput = previouRoute.outputs.firstObject;
        NSString *portType = previousputput.portType;
        if ([portType isEqualToString:AVAudioSessionPortHeadphones]) {
            [self stopRecord];
        }
    }
    
}

#pragma mark - 基础配置
/**
 *  设置录制的音频文件的位置
 *
 *  @return string
 */

- (NSString *)audioRecordingPath {
    NSString *result = nil;
    result = [NSString stringWithFormat:@"%@/%d.aac", self.audioPath, (int)[NSDate date].timeIntervalSince1970];
    return result;
}

/**
 *  目录文件夹的位置
 *
 *  @return string
 */
- (NSString *)audioPath {
    if (!_audioPath) {
        _audioPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", JZ_Audio_RECORD_DIR, self.rootPath]];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_audioPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_audioPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return _audioPath;
}

/**
 *  在初始化AVAudioRecord实例之前，需要进行基本的录音设置
 *
 *  @return 录音设置
 */
- (NSDictionary *)recordingSettings {
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithInt:kAudioFormatMPEG4AAC],AVFormatIDKey,  //录音格式
                              [NSNumber numberWithFloat:44100.0],AVSampleRateKey,    //采样率 8000/44100/96000
                              [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,    //线性采样位数  8、16、24、32
                              [NSNumber numberWithInt:1],AVNumberOfChannelsKey,      //声道 1,2 //移动端用1就行
                              [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,//大端还是小端是内存的组织方式
                              [NSNumber numberWithInt:AVAudioQualityMedium],AVEncoderAudioQualityKey, //录音质量
                              [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,    //是否支持浮点处理
                              [NSNumber numberWithInt:16], AVEncoderBitDepthHintKey,  //编码比特率深度16位
                              [NSNumber numberWithInt:64000], AVEncoderBitRateKey,   //编码比特率 bps
                              AVAudioBitRateStrategy_VariableConstrained,AVEncoderBitRateStrategyKey, // 比特率策略为可变约束
                              nil];
    return settings;
}

@end
