//
//  JZAudioPlayerView.m
//  JZMediaModule
//
//  Created by Jesse on 2023/6/19.
//

#import "JZAudioPlayerView.h"
#import <JZMediaModule/JZVisitRecordPlayView.h>
#import <JZMediaModule/JZVisitAudioRecorder.h>

@import Masonry;
@import JZUIKit;

@interface JZAudioPlayerView ()

@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) JZVisitRecordPlayView *recordPlayView; //录音播放视图
@property (nonatomic, strong) UIView *lineView;        //竖条视图
@property (nonatomic, strong) UIButton *deleteBtn;     //删除按钮

@property (nonatomic, strong) NSNumber *showDelete;

@property (nonatomic, strong) JZAudioPlayerViewModel *model;
@end

@implementation JZAudioPlayerView

- (instancetype)initWithModel:(JZAudioPlayerViewModel *)model {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        [self updatePlayModel:model];
        
        [self initViews];
    }
    return self;
}

- (void)updatePlayModel:(JZAudioPlayerViewModel *)model {
    if (!model || !model.urlValue) return;
    
    _model = model;
    if (model.urlType == JZAudioPlayerViewUrlTypeFromLocal) {
        self.recordPlayView.recordUrl = [NSURL fileURLWithPath:model.urlValue];
    } else {
        self.recordPlayView.recordUrl = [NSURL URLWithString:model.urlValue];
    }
    self.recordPlayView.duration = model.duration;
    //已听数据上报数据需要
    self.recordPlayView.recordingId = model.recordingId;
    self.recordPlayView.needUpload = model.needUpload.boolValue;
}

- (void)initViews {
    [self addSubview:self.bgView];
    [self.bgView mas_makeConstraints:^(MASConstraintMaker * _Nonnull make) {
        make.edges.equalTo(self);
    }];
    
    if (self.model.showDelete.boolValue) {
        [self.bgView addSubview:self.recordPlayView];
        [self.bgView addSubview:self.lineView];
        [self.bgView addSubview:self.deleteBtn];
        [self.recordPlayView mas_makeConstraints:^(MASConstraintMaker * _Nonnull make) {
            make.left.top.bottom.equalTo(self.bgView);
            make.right.equalTo(self.bgView).offset(-36);
        }];
        [self.lineView mas_makeConstraints:^(MASConstraintMaker * _Nonnull make) {
            make.left.equalTo(self.recordPlayView.mas_right);
            make.centerY.equalTo(self.bgView);
            make.size.mas_equalTo(CGSizeMake(0.5, 13));
        }];
        [self.deleteBtn mas_makeConstraints:^(MASConstraintMaker * _Nonnull make) {
            make.right.equalTo(self.bgView).offset(-1);
            make.size.mas_equalTo(CGSizeMake(34, 34));
            make.centerY.equalTo(self.bgView);
        }];
    } else {
        [self.bgView addSubview:self.recordPlayView];
        [self.recordPlayView mas_makeConstraints:^(MASConstraintMaker * _Nonnull make) {
            make.left.top.bottom.equalTo(self.bgView);
            make.right.equalTo(self.bgView);
        }];
    }
}

#pragma mark - actions
- (void)deleteBtnAction:(id)sender {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:@"确定删除录音？" message:@"删除后，录音将不可恢复。" preferredStyle:UIAlertControllerStyleAlert];
    [vc addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [vc addAction:[UIAlertAction actionWithTitle:@"删除录音" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if (self.model.urlType == JZAudioPlayerViewUrlTypeFromLocal) {
            [[JZVisitAudioRecorder shareAudioRecorder] removeCurrentFilePath:self.model.urlValue removeBlock:^(BOOL status, JZVisitAudioRecordRemoveDirStatus detailStatus, NSString * _Nonnull errMessage) {
                if (status) {
                    [EVEUtil showMessage:@"删除成功"];
                    [[NSNotificationCenter defaultCenter] postNotificationName:JZRecordPlayerReceiveDeleteMessageNotification object:nil userInfo:@{JZRecordPlayerReceiveUrlPath : self.model.urlValue ?: @""}];
                    if (self.deleteBlock) {
                        self.deleteBlock();
                    }
                } else {
                    [EVEUtil showMessage:errMessage];
                }
                
//                [JZLogManager logRemoteCustom:@"visit" metricName:@"visit_voice_record_delete"
//                                       fileds:@{@"status":@(1)}
//                                         tags:nil
//                                       extras:@{@"type" : @"local",
//                                                @"status" : @(status),
//                                                @"message" : errMessage ?: @"unknown"}];
            }];
        } else {
            //服务下发的模型数据删除
            [EVEUtil showMessage:@"删除成功"];
            if (self.deleteBlock) {
                self.deleteBlock();
            }
            
//            [JZLogManager logRemoteCustom:@"visit" metricName:@"visit_voice_record_delete"
//                                   fileds:@{@"status":@(1)}
//                                     tags:nil
//                                   extras:@{@"type": @"server"
//                                          }];
        }
    }]];
    [[UIViewController JZ_visiableViewController] presentViewController:vc animated:YES completion:nil];
}

#pragma mark - properties
- (UIView *)bgView {
    if (!_bgView) {
        _bgView = [UIView new];
    }
    return _bgView;
}

- (JZVisitRecordPlayView *)recordPlayView {
    if (!_recordPlayView) {
        _recordPlayView = [[JZVisitRecordPlayView alloc] init];
    }
    return _recordPlayView;
}

- (UIView *)lineView {
    if (!_lineView) {
        _lineView = [UIView new];
        _lineView.backgroundColor = [UIColor colorWithHex:0xC7CCD4];
    }
    return _lineView;
}

- (UIButton *)deleteBtn {
    if (!_deleteBtn) {
        _deleteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_deleteBtn setImageEdgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
        [_deleteBtn setImage:[UIImage JZ_imageNamedInJZUIKit:@"icon_delete_gray"] forState:UIControlStateNormal];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(deleteBtnAction:)];
        [_deleteBtn addGestureRecognizer:tap];
    }
    return _deleteBtn;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
