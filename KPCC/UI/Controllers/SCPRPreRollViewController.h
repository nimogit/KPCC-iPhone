//
//  SCPRPreRollViewController.h
//  KPCC
//
//  Created by John Meeker on 10/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TritonAd.h"
#import "SCPRAppDelegate.h"

@import AVFoundation;

@protocol SCPRPreRollControllerDelegate <NSObject>

- (void)preRollStartedPlaying;
- (void)preRollCompleted;

@end

@interface SCPRPreRollViewController : UIViewController

- (void)showPreRollWithAnimation:(BOOL)animated completion:(void (^)(BOOL done))completion;
- (void)setAdProgress;
- (void)primeUI:(CompletionBlock)completed;

@property (nonatomic, strong) UITapGestureRecognizer *adTapper;
@property (nonatomic,weak) id<SCPRPreRollControllerDelegate> delegate;
@property (nonatomic,strong) TritonAd *tritonAd;
@property (nonatomic,strong) IBOutlet UIImageView *adImageView;
@property (nonatomic,strong) IBOutlet UIView *curtainView;

@property (nonatomic,strong) AVPlayer *prerollPlayer;

@property (nonatomic, strong) id timeObserver;

@end
