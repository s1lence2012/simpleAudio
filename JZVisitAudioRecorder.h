//
//  JZVisitAudioRecorder.h
//  JZShopModule
//
//  Created by jesse on 2023/4/24.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JZVisitAudioRecordOperateType) {
    JZVisitAudioRecordOperateTypePlaySuccess,          //播放成功
    JZVisitAudioRecordOperateTypeAuthorizationDenied,  //没有权限
    JZVisitAudioRecordOperateTypeInitFailed,           //初始化失败
    JZVisitAudioRecordOperateTypeCreateAudioFileFailed,//录音文件创建失败
    JZVisitAudioRecordOperateTypeMultiRequest,         //多次请求
    JZVisitAudioRecordOperateTypeRecordError,          //录制失败
    
    JZVisitAudioRecordOperateTypeStopSuccess,          //停止成功
    JZVisitAudioRecordOperateTypeStopFailed,           //停止失败 未在播放中,无需停止
};

typedef NS_ENUM(NSInteger, JZVisitAudioRecordRemoveDirStatus) {
    JZVisitAudioRecordRemoveDirStatusWithoutDir,  //没有该目录文件夹
    JZVisitAudioRecordRemoveDirStatusParamError,  //目录参数错误
    JZVisitAudioRecordRemoveDirStatusSuccess,     //删除成功
    JZVisitAudioRecordRemoveDirStatusFail,        //删除失败
};

//播放、暂停回调
typedef void(^JZVisitAudioRecordChangeStatusBlock)(BOOL status, JZVisitAudioRecordOperateType errorType, NSString *errMessage);
//获取播放状态回调
typedef void(^JZVisitAudioRecorderStatusBlock)(BOOL status, NSTimeInterval duration, NSTimeInterval timeout);
//删除回调
typedef void(^JZVisitAudioRecorderRemoveBlock)(BOOL status, JZVisitAudioRecordRemoveDirStatus removeStatus, NSString *errMessage);

@interface JZVisitAudioRecorder : NSObject <AVAudioRecorderDelegate>

+ (JZVisitAudioRecorder *)shareAudioRecorder;

- (void)startRecordWithRootPath:(NSString *)rootPath timeout:(NSTimeInterval)timeout block:(JZVisitAudioRecordChangeStatusBlock)block;
- (void)stopRecord;
- (void)stopRecordWithBlock:(__nullable JZVisitAudioRecordChangeStatusBlock)stopBlock;

//获取录音播放状态
- (void)getIsRecordingStatusWithBlock:(JZVisitAudioRecorderStatusBlock)block;

/**
 *  音频目录文件夹处理
 *
 */
//获取录音文件 <打卡目录下>
- (NSArray <NSString *>*)returnFilesInRootPath:(NSString *)rootPath;
//删除
//传入完整的路径（删除单个录音文件）
- (void)removeCurrentFilePath:(NSString *)path removeBlock:(JZVisitAudioRecorderRemoveBlock)removeBlock;
//传入次级文件夹名称（删除次级文件夹以内的所有录音文件）
- (void)removeCurrentRootPathDirFiles:(NSString *)rootPath removeBlock:(JZVisitAudioRecorderRemoveBlock)removeBlock;
//删除一级录音目录文件夹（删除所有录音文件）
- (void)removeAllAudioRecordFilesBlock:(JZVisitAudioRecorderRemoveBlock)block;

@end

NS_ASSUME_NONNULL_END
