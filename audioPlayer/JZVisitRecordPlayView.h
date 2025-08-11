//
//  JZVisitRecordPlayView.h
//
//  Created by Jesse on 2023/4/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const JZRecordPlayerReceiveDeleteMessageNotification;
extern NSString * const JZRecordPlayerReceiveUrlPath;

@interface JZVisitRecordPlayView : UIView

@property (nonatomic, strong) NSNumber *recordingId; //录音id (选传)
@property (nonatomic, strong) NSURL *recordUrl;      //音频资源地址 (必传)
@property (nonatomic, strong) NSNumber *duration;    //时长 (s)
@property (nonatomic, assign) BOOL needUpload;  //是否需要调取上传服务 (选传)
@property (nonatomic, strong) NSMutableDictionary *uploadServiceParameters;//上传服务 (选传)

@end

NS_ASSUME_NONNULL_END
