//
//  JZAudioPlayerView.h
//  JZMediaModule
//
//  Created by Jesse on 2023/6/19.
//

#import <UIKit/UIKit.h>
#import <JZMediaModule/JZAudioPlayerViewModel.h>
@import JZFoundation;

NS_ASSUME_NONNULL_BEGIN
typedef void(^JZVisitRecordPlayCellOneBlock)(void);

@interface JZAudioPlayerView : UIView

@property (nonatomic, copy) JZVisitRecordPlayCellOneBlock deleteBlock;

- (instancetype)initWithModel:(JZAudioPlayerViewModel *)model;
- (void)updatePlayModel:(JZAudioPlayerViewModel *)model;

@end

NS_ASSUME_NONNULL_END
