//
//  SCPRMasterViewController.h
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Utils.h"
#import "AudioManager.h"
#import "NetworkManager.h"
#import "DesignManager.h"
#import "QueueManager.h"
#import "Program.h"
#import "FXBlurView.h"
#import "SCPRPullDownMenu.h"
#import "Episode.h"
#import "Segment.h"
#import "SCPRJogShuttleViewController.h"
#import "SCPRPreRollViewController.h"
#import "SCPRProgressViewController.h"
#import "SCPRButton.h"
#import "SCPRScrubbingUIViewController.h"
#import "SCPRTouchableScrubberView.h"
#import "SCPRUpcomingProgramViewController.h"
#import "SCPRCompleteScheduleViewController.h"
#import "SCPRBalloonViewController.h"
#import "GenericProgram.h"

@import MessageUI;

@interface SCPRMasterViewController : UIViewController<SCPRMenuDelegate,UIAlertViewDelegate,UIScrollViewDelegate,MFMailComposeViewControllerDelegate>

@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *programImageView;
@property IBOutlet SCPRButton *playPauseButton;
@property IBOutlet SCPRButton *initialPlayButton;
@property IBOutlet UIButton *rewindToShowStartButton;
@property IBOutlet SCPRButton *liveRewindAltButton;
@property IBOutlet UILabel *liveDescriptionLabel;
@property IBOutlet UIView *horizDividerLine;
@property IBOutlet UIButton *backToLiveButton;
@property IBOutlet FXBlurView *blurView;
@property IBOutlet UIView *darkBgView;


@property IBOutlet UIScrollView *mainContentScroller;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *mainHeightConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *cpHeightConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *fsHeightConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *cpWidthConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *fsWidthConstraint;

@property (nonatomic, strong) IBOutlet SCPRUpcomingProgramViewController *upcomingScreen;
@property (nonatomic, strong) IBOutlet SCPRCompleteScheduleViewController *cpFullDetailScreen;
@property (nonatomic,strong) MPVolumeView *mpvv;
- (void)setupScroller;

@property NSInteger tickCounter;

// For audio queue
@property (nonatomic,strong) UIScrollView *queueScrollView;
@property (nonatomic) int queueCurrentPage;
@property IBOutlet UIImageView *queueBlurView;
@property IBOutlet UIView *queueDarkBgView;
@property (nonatomic,strong) NSTimer *queueScrollTimer;
@property (nonatomic,strong) NSArray *queueContents;
@property (nonatomic,strong) NSMutableArray *queueUIContents;

// Major holder views for different playback states.
@property IBOutlet UIView *liveStreamView;
@property IBOutlet UIView *onDemandPlayerView;
@property IBOutlet UIView *playerControlsView;
@property IBOutlet UIView *initialControlsView;


// Views for On-Demand playback;
@property IBOutlet UILabel *programTitleOnDemand;
@property IBOutlet UIView *dividerOnDemand;
@property IBOutlet UILabel *timeLabelOnDemand;
@property IBOutlet SCPRButton *shareButton;
@property IBOutlet UIProgressView *progressView;
@property IBOutlet UIView *onDemandMainDividerView;

- (void)onDemandFadeDown;


// Important Attrs.
@property (nonatomic,strong) Program *currentProgram;
@property (nonatomic,strong) Program *onDemandProgram;
@property (nonatomic,strong) NSString *onDemandEpUrl;
@property (nonatomic,strong) SCPRPullDownMenu *pulldownMenu;
@property (nonatomic) BOOL menuOpen;
@property (nonatomic) BOOL preRollOpen;
@property (nonatomic) BOOL streamSelectorOpen;

// Controllable Constraints
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *initialControlsYConstraint;

// Live
@property (nonatomic,strong) SCPRProgressViewController *liveProgressViewController;
@property (nonatomic,strong) IBOutlet UIView *liveProgressView;
@property (nonatomic,strong) IBOutlet UIView *currentProgressBarView;
@property (nonatomic,strong) IBOutlet UIView *liveProgressBarView;
@property IBOutlet NSLayoutConstraint *horizontalDividerPush;
@property (nonatomic,strong) IBOutlet SCPRButton *mainBackward30Button;
@property (nonatomic,strong) IBOutlet SCPRButton *mainForward30Button;
@property (nonatomic,strong) NSTimer *liveScrollTimer;

// Pre-Roll
@property (nonatomic,strong) SCPRPreRollViewController *preRollViewController;
@property BOOL lockPreroll;
@property BOOL updaterArmed;

// Rewinding UI
@property (nonatomic,strong) SCPRJogShuttleViewController *jogShuttle;
@property (nonatomic,strong) IBOutlet UIView *rewindView;
@property (nonatomic,strong) NSMutableDictionary *originalFrames;

@property (nonatomic, strong) IBOutlet NSLayoutConstraint *liveRewindBottomYConstraint;
@property BOOL shuttlingGate;
@property BOOL initiateRewind;
@property BOOL rewindNeedsUIRefresh;
@property BOOL springLock;
@property BOOL lockPlayback;
@property BOOL lockAnimationUI;
@property BOOL promptedAboutFailureAlready;
@property BOOL recovering;
@property BOOL uiLocked;
@property BOOL dirtyFromFailure;
@property BOOL audioWasPlaying;
@property BOOL scrubberLoadingGate;
@property BOOL playStateGate;
@property BOOL onDemandPanning;
@property BOOL onDemandFailing;

@property CGFloat initialProgramTitleConstant;
@property CGFloat deployedProgramTitleConstant;
@property CGFloat threePointFivePlayControlsConstant;

// Onboarding
@property BOOL automationMode;
@property BOOL trainingUIisExposed;
@property BOOL showLiveHelpScreens;

@property (nonatomic,strong) IBOutlet UILabel *letsGoLabel;

- (void)activateRewind:(RewindDistance)distance;
- (void)activateFastForward;
- (void)snapJogWheel;
- (void)specialRewind;

- (void)adjustScrollingState;
- (void)adjustScrubbingState;

// Scrubbing
- (void)bringUpScrubber;
- (void)cloakForScrubber;
- (void)decloakForScrubber;
- (void)primeScrubber;
- (void)addCloseButton;
- (void)killCloseButton;
- (void)finishedWithScrubber;
- (void)tickOnDemand;
- (void)beginScrubbingWaitMode;
- (void)endScrubbingWaitMode;
- (void)animatedStateForButton:(UIButton*)button enabled:(BOOL)enabled;
- (void)animatedStateForForwardButton:(BOOL)enabled;
- (void)animatedStateForBackwardButton:(BOOL)enabled;
- (void)wipeTargetsForScrubButtons;
- (void)dismissXFSCoachingBalloon;

@property (nonatomic, strong) SCPRScrubbingUIViewController *scrubbingUI;
@property (nonatomic, strong) SCPRButton *scrubberCloseButton;
@property (nonatomic, strong) IBOutlet UIView *scrubbingUIView;
@property (nonatomic, strong) IBOutlet SCPRButton *back30Button;
@property (nonatomic, strong) IBOutlet SCPRButton *fwd30Button;
@property (nonatomic, strong) IBOutlet UIView *scrubberControlView;
@property (nonatomic, strong) IBOutlet UILabel *scrubberTimeLabel;
@property (nonatomic, strong) IBOutlet SCPRTouchableScrubberView *touchableScrubberView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *topYScrubbingAnchor;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *back30VerticalAnchor;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *fwd30VerticalAnchor;
@property (nonatomic, strong) IBOutlet UILabel *lowerBoundScrubberLabel;
@property (nonatomic, strong) IBOutlet UILabel *upperBoundScrubberLabel;
@property (nonatomic, strong) IBOutlet UILabel *timeBehindLiveScrubberLabel;
@property (nonatomic, strong) IBOutlet UILabel *timeNumbericScrubberLabel;
@property (nonatomic, strong) IBOutlet UIView *liveProgressScrubberView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *liveProgressScrubberAnchor;
@property IBOutlet NSLayoutConstraint *topGapScrubbingAnchor;
@property IBOutlet NSLayoutConstraint *dividerLineLeftAnchor;
@property IBOutlet NSLayoutConstraint *dividerLineRightAnchor;
@property IBOutlet NSLayoutConstraint *scrollerTopConstraint;

@property (nonatomic, strong) NSMutableArray *hiddenVector;
- (void)pushToHiddenVector:(UIView*)viewToHide;
- (void)commitHiddenVector;
- (void)popHiddenVector;

@property (nonatomic,strong) UIView *scrubbingTriggerView;

@property BOOL scrubbing;
@property BOOL viewHasAppeared;
@property BOOL hiddenVectorCommitted;
@property BOOL lockUIFromDeceleration;
@property BOOL restoreTitle;

// Sleep Timer
@property (nonatomic, strong) IBOutlet UIView *sleepTimerContainerView;
@property (nonatomic, strong) IBOutlet UIProgressView *sleepTimerCountdownProgress;
@property (nonatomic, strong) IBOutlet UIImageView *clockIconImageView;
@property (nonatomic, strong) IBOutlet UILabel *plainTextCountdownLabel;
@property (nonatomic, strong) IBOutlet UIButton *cancelSleepTimerButton;

- (void)setupTimerControls;
- (void)cancelSleepTimerAction;
- (void)remoteControlPlayOrPause;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL uiIsJogging;

// Instance methods.
- (void)cloakForMenu:(BOOL)animated;
- (void)cloakForMenu:(BOOL)animated suppressDropdown:(BOOL)suppressDropdown;
- (void)decloakForMenu:(BOOL)animated;



- (void)setOnDemandUI:(BOOL)animated forProgram:(Program*)program withAudio:(NSArray*)array atCurrentIndex:(int)index;
- (void)setLiveStreamingUI:(BOOL)animated;
- (void)setPositionForQueue:(int)index animated:(BOOL)animated;
- (void)primeManualControlButton;
- (void)treatUIforProgram;
- (void)determinePlayState;

- (void)mutePrimaryControls;
- (void)unmutePrimaryControls;

- (void)handleAlarmClock;

- (void)moveTextIntoPlace:(BOOL)animated;
- (void)goLive:(BOOL)play;
- (void)goLive:(BOOL)play smooth:(BOOL)smooth;
- (void)warnUserOfOnDemandFailures;

- (void)resetUI;

// Onboarding methods
- (void)primeOnboarding;
- (void)onboarding_revealPlayerControls;
- (void)onboarding_beginOnboardingAudio;
- (void)onboarding_rewindToBeginning;
- (void)onboarding_beginOutro;
- (void)onboarding_fin;

- (void)superPop;

@property (nonatomic, strong) IBOutlet NSLayoutConstraint *imageTopConstraint;

@property BOOL genericImageForProgram;
@property BOOL onboardingRewindButtonShown;
@property BOOL homeIsNotRootViewController;

- (BOOL)cloaked;

- (void)showOnDemandOnboarding;
- (void)prettifyBehindLiveStatus;
- (void)handleResponseForNotification;

// XFS
- (void)cloakForXFS;
- (void)decloakForXFS;
- (void)showBalloonWithText:(NSString*)text;

- (void)trackSchedulingSwipes;

- (void)composeMail:(NSNotification*)note;
@property (nonatomic, strong) MFMailComposeViewController *mComposer;
@property BOOL mailCompositionDisplaying;

@property BOOL userIsLoggingIn;

- (IBAction)initialPlayTapped:(id)sender;

@end
