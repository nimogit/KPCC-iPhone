//
//  SCPRTimerControlViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 3/19/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRButton.h"

@class SCPRSleepViewController;
@class SCPRAlarmClockViewController;

@interface SCPRTimerControlViewController : UIViewController<UIGestureRecognizerDelegate>

@property (nonatomic, strong) IBOutlet UIView *buttonSeatView;
@property (nonatomic, strong) IBOutlet UIView *duckDuckGooseView;
@property (nonatomic, strong) IBOutlet SCPRButton *sleepTimerButton;
@property (nonatomic, strong) IBOutlet SCPRButton *alarmClockButton;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *ddgCenterXAnchor;
@property (nonatomic, strong) IBOutlet UIScrollView *toggleScroller;
@property (nonatomic, strong) IBOutlet UIImageView *blurredImageView;
@property (nonatomic, strong) IBOutlet UIView *chromaKeyView;

@property (nonatomic, strong) SCPRSleepViewController *sleepTimerController;
@property (nonatomic, strong) SCPRAlarmClockViewController *alarmClockController;

@property (nonatomic, weak) SCPRButton *selectedButton;

- (void)setup;

@end
