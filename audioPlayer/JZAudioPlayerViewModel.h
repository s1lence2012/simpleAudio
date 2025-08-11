//
//  JZAudioPlayerViewModel.h
//
//  Created by Jesse on 2023/6/20.
//

#import <JZFoundation/JZFoundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, JZAudioPlayerViewUrlType) {
    JZAudioPlayerViewUrlTypeFromNone,
    JZAudioPlayerViewUrlTypeFromLocal,   //本地文件
    JZAudioPlayerViewUrlTypeFromServer   //服务下发的文件
};


@interface JZAudioPlayerViewModel : EVEModel

@property (nonatomic, copy) NSString *type;
@property (nonatomic, strong) NSNumber *recordingId;
@property (nonatomic, copy) NSString *urlValue;
@property (nonatomic, copy) NSString *hashValue;
@property (nonatomic, strong) NSNumber *duration;

//extra key
@property (nonatomic, assign) JZAudioPlayerViewUrlType urlType;
//view
@property (nonatomic, strong) NSNumber *showDelete;
@property (nonatomic, strong) NSNumber *needUpload;


@end

NS_ASSUME_NONNULL_END
