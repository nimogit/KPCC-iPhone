//
//  SCPRScrubbingUIViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRScrubberViewController.h"
#import "Program.h"
#import "AudioChunk.h"
#import "AudioManager.h"
#import "SCPRButton.h"

@interface SCPRScrubbingUIViewController : UIViewController<AudioManagerDelegate,Scrubbable>

@property (nonatomic,strong) IBOutlet UIButton *closeButton;
@property (nonatomic,strong) IBOutlet UILabel *captionLabel;
@property (nonatomic,strong) IBOutlet UIView *scrubberSeatView;
@property (nonatomic,strong) IBOutlet SCPRButton *rw30Button;
@property (nonatomic,strong) IBOutlet UIButton *playPauseButton;
@property (nonatomic,strong) IBOutlet SCPRButton *fw30Button;
@property (nonatomic,strong) IBOutlet UIImageView *blurredImageView;
@property (nonatomic,strong) IBOutlet UIView *darkeningView;
@property (nonatomic,strong) IBOutlet UILabel *lowerBoundLabel;
@property (nonatomic,strong) IBOutlet UILabel *upperBoundLabel;
@property (nonatomic,strong) IBOutlet UILabel *timeBehindLiveLabel;
@property (nonatomic,strong) IBOutlet UILabel *timeNumericLabel;
@property (nonatomic,strong) IBOutlet UIView *liveProgressView;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *liveStreamProgressAnchor;
@property (nonatomic,strong) IBOutlet UIView *liveProgressNeedleView;
@property (nonatomic,strong) IBOutlet UILabel *liveProgressNeedleReadingLabel;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *flagAnchor;
@property BOOL ignoringThresholdGate;

@property CGFloat tolerance;

@property NSTimer *seekLatencyTimer;

@property (nonatomic,strong) SCPRScrubberViewController *scrubberController;
@property (nonatomic,weak) id parentControlView;
@property CMTime lowerBoundThreshold;

- (void)prerender;
- (void)setupWithProgram:(NSDictionary*)program blurredImage:(UIImage*)image parent:(id)parent;
- (void)takedown;
- (void)scrubberWillAppear;
- (void)updateTimeBehindHUD;

// Seeking
- (void)muteUI;
- (void)unmuteUI;
- (void)killLatencyTimer;
- (void)audioWillSeek;
- (void)primeForAudioMode;

// Live
- (double)livePercentage;
- (double)percentageThroughCurrentProgram;
- (void)tickLive:(BOOL)animated;
- (CMTime)convertToTimeValueFromPercentage:(double)percent;
- (void)recalibrateAfterScrub;
- (void)behindLiveStatus;

- (double)strokeEndForCurrentTime;

@property BOOL uiIsMutedForSeek;
@property CGFloat maxPercentage;

@end
