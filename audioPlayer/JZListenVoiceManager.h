//
//  JZListenVoiceManager.h
//
//  Created by Jesse on 2021/7/15.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef enum : NSUInteger {
    JZAVPlayStatus_readyToPlay,  //准备播放 (资源加载完成,可以使用)
    JZAVPlayStatus_end,          //播放完成
} JZAVPlayStatus;


@protocol JZListenVoiceManagerDelegate <NSObject>

- (void)JZAVPlayWithCurrentTime:(NSInteger)currentTime;//资源当前时长(S)
- (void)JZAVPlayStatusChange:(JZAVPlayStatus)status message:(NSString *)message;//播放状态更新

@end

@interface JZListenVoiceManager : NSObject

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, assign) NSTimeInterval totalTime;//总时长
@property (nonatomic, assign) BOOL isPlay;
@property (nonatomic, weak) id<JZListenVoiceManagerDelegate> delegate;

- (instancetype)initWithURL:(NSURL *)playItemURL;
- (void)play;  //开始播放
- (void)pause; //暂停播放
- (void)stop;  //停止播放 -> 播放完毕(暂停, 恢复初始状态)

- (NSString *)intervalTimeToString:(NSTimeInterval)interval;
//跳转多少秒
- (void)seekToTime:(NSTimeInterval)time block:(void (^)(BOOL finish))block;

@end

NS_ASSUME_NONNULL_END
