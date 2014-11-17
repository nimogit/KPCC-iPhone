//
//  SCPRMasterViewController.m
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMasterViewController.h"
#import "SCPRMenuButton.h"
#import "SCPRProgramsListViewController.h"
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"
#import "SCPRSlideInTransition.h"
#import "SCPRShortListViewController.h"
#import "SCPRQueueScrollableView.h"
#import "NSDate+Helper.h"
#import "SessionManager.h"
#import "SCPRCloakViewController.h"
#import "SCPRFeedbackViewController.h"

static NSString *kRewindingText = @"REWINDING...";
static NSString *kForwardingText = @"GOING LIVE...";
static CGFloat kRewindGateThreshold = 8.0;
static CGFloat kDisabledAlpha = 0.15;

@interface SCPRMasterViewController () <AudioManagerDelegate, UINavigationControllerDelegate, UIViewControllerTransitioningDelegate, SCPRPreRollControllerDelegate, UIScrollViewDelegate>

@property BOOL initialPlay;
@property BOOL setPlaying;
@property BOOL seekRequested;
@property BOOL busyZoomAnim;
@property BOOL jogging;
@property BOOL setForLiveStreamUI;
@property BOOL setForOnDemandUI;
@property BOOL dirtyFromRewind;
@property BOOL queueBlurShown;
@property BOOL queueLoading;

@property IBOutlet NSLayoutConstraint *playerControlsTopYConstraint;
@property IBOutlet NSLayoutConstraint *playerControlsBottomYConstraint;
@property IBOutlet NSLayoutConstraint *rewindWidthConstraint;
@property IBOutlet NSLayoutConstraint *rewindHeightContraint;
@property IBOutlet NSLayoutConstraint *programTitleYConstraint;




@end

@implementation SCPRMasterViewController

@synthesize pulldownMenu,
            seekRequested,
            initialPlay,
            setPlaying,
            busyZoomAnim,
            setForLiveStreamUI,
            setForOnDemandUI;

#pragma mark - UIViewController

// Allows for interaction with system audio controls.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    // Handle remote audio control events.
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay ||
            event.subtype == UIEventSubtypeRemoteControlPause ||
            event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
//            [self playOrPauseTapped:nil];
        } else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack) {
//            [self nextEpisodeTapped:nil];
        } else if (event.subtype == UIEventSubtypeRemoteControlNextTrack) {
//            [self prevEpisodeTapped:nil];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.horizDividerLine.layer.opacity = 0.0;

    self.initialControlsView.backgroundColor = [UIColor redColor];
    self.initialPlayButton.backgroundColor = [UIColor blueColor];
    
    
    self.liveProgressViewController = [[SCPRProgressViewController alloc] init];
    self.liveProgressViewController.view = self.liveProgressView;
    self.liveProgressViewController.liveProgressView = self.liveProgressBarView;
    self.liveProgressViewController.currentProgressView = self.currentProgressBarView;
    self.playerControlsView.backgroundColor = [UIColor clearColor];
    
    
    
    self.liveRewindAltButton.userInteractionEnabled = NO;
    [self.liveRewindAltButton setAlpha:0.0];
    
    pulldownMenu = [[SCPRPullDownMenu alloc] initWithView:self.view];
    pulldownMenu.delegate = self;
    [self.view addSubview:pulldownMenu];
    [pulldownMenu loadMenu];

    // Set up pre-roll child view controller.
    [self addPreRollController];

    // Fetch program info and update audio control state.
    //[self updateDataForUI];

    // Observe when the application becomes active again, and update UI if need-be.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDataForUI) name:UIApplicationWillEnterForegroundNotification object:nil];

    // Make sure the system follows our playback status - to support the playback when the app enters the background mode.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive: YES error: nil];
    
    // Config blur view.
    [self.blurView setAlpha:0.0];
    [self.blurView setTintColor:[UIColor clearColor]];
    [self.blurView setBlurRadius:20.0f];
    [self.blurView setDynamic:NO];
    
    // Config dark background view. Will sit on top of blur view, between player controls view.
    [self.darkBgView setAlpha:0.0];

    // Initially flag as KPCC Live view
    setForLiveStreamUI = YES;
    [self primeRemoteCommandCenter:YES];

    self.jogShuttle = [[SCPRJogShuttleViewController alloc] init];
    self.jogShuttle.view = self.rewindView;
    self.jogShuttle.view.alpha = 0.0;
    [self.jogShuttle prepare];

    // Views for audio queue
    self.queueScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 64, self.view.frame.size.width, self.timeLabelOnDemand.frame.origin.y - 64)];
    self.queueScrollView.backgroundColor = [UIColor clearColor];
    self.queueScrollView.pagingEnabled = YES;
    self.queueScrollView.delegate = self;
    self.queueScrollView.hidden = YES;
    [self.view insertSubview:self.queueScrollView belowSubview:self.initialControlsView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(treatUIforProgram)
                                                 name:@"program_has_changed"
                                               object:nil];
    
    [self.queueBlurView setAlpha:0.0];
    [self.queueBlurView setTintColor:[UIColor clearColor]];
    [self.queueBlurView setBlurRadius:20.0f];
    [self.queueBlurView setDynamic:NO];
    [self.queueDarkBgView setAlpha:0.0];
    
    self.view.alpha = 0.0;
    [SCPRCloakViewController cloakWithCustomCenteredView:nil cloakAppeared:^{
        [self updateDataForUI];
    }];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [AudioManager shared].delegate = self;

    if (self.menuOpen) {
        self.navigationItem.title = @"Menu";
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.blurView setNeedsDisplay];
    [self.queueBlurView setNeedsDisplay];

    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.queueBlurView.alpha = 0.0;
    self.queueDarkBgView.alpha = 0.0;
}

- (void)addPreRollController {
    self.preRollViewController = [[SCPRPreRollViewController alloc] initWithNibName:nil bundle:nil];
    self.preRollViewController.delegate = self;

    [[NetworkManager shared] fetchTritonAd:nil completion:^(TritonAd *tritonAd) {
        self.preRollViewController.tritonAd = tritonAd;
    }];

    [self addChildViewController:self.preRollViewController];

    CGRect frame = self.view.bounds;
    frame.origin.y = (-1)*self.view.bounds.size.height;
    self.preRollViewController.view.frame = frame;

    [self.view addSubview:self.preRollViewController.view];
    [self.preRollViewController didMoveToParentViewController:self];
}


# pragma mark - Actions

- (IBAction)initialPlayTapped:(id)sender {
    if (self.preRollViewController.tritonAd) {
        [self cloakForPreRoll:YES];
        [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {
            [self moveTextIntoPlace:NO];
        }];
    } else {
        [self primePlaybackUI:YES];
        [self moveTextIntoPlace:YES];
    }
}

- (IBAction)playOrPauseTapped:(id)sender {
    if (seekRequested) {
        seekRequested = NO;
    }

    if (![[AudioManager shared] isStreamPlaying]) {
        if ( [[SessionManager shared] sessionIsExpired] ) {
            [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
                self.setPlaying = YES;
                
                if ([[AudioManager shared] isStreamBuffering]) {
                    [[AudioManager shared] stopAllAudio];
                } else {
                    [self playStream];
                }
            }];
        } else {
            self.setPlaying = YES;
            
            if ([[AudioManager shared] isStreamBuffering]) {
                [[AudioManager shared] stopAllAudio];
            } else {
                [self playStream];
            }
        }

    } else {
        self.setPlaying = NO;

        [self pauseStream];
    }
    
}

- (IBAction)rewindToStartTapped:(id)sender {

    if ( self.jogging ) return;

    [self activateRewind:RewindDistanceBeginning];
    
}

- (IBAction)prevEpisodeTapped:(id)sender {
    [[QueueManager shared] playPrev];
}
- (IBAction)nextEpisodeTapped:(id)sender {
    [[QueueManager shared] playNext];
}

/**
 * For MPRemoteCommandCenter - see [self primeRemoteCommandCenter]
 */
- (void)pauseTapped:(id)sender {
    if ([[AudioManager shared] isStreamPlaying]) {
        self.setPlaying = NO;
        [self pauseStream];
    }
}
- (void)playTapped:(id)sender {
    if (![[AudioManager shared] isStreamPlaying]) {
        self.setPlaying = YES;
        if ([[AudioManager shared] isStreamBuffering]) {
            [[AudioManager shared] stopAllAudio];
        }
        [self playStream];
    }
}

- (void)snapJogWheel {
    UIImage *pause = self.playPauseButton.imageView.image;
    CGFloat ht = pause.size.height; CGFloat wd = pause.size.width;
    [self.rewindHeightContraint setConstant:ht];
    [self.rewindWidthConstraint setConstant:wd];
    [self.playerControlsView layoutIfNeeded];
}


- (NSTimeInterval)rewindAgainstStreamDelta {
    AVPlayerItem *item = [[AudioManager shared].audioPlayer currentItem];
    NSTimeInterval current = [item.currentDate timeIntervalSince1970];
    
    if ( [[SessionManager shared] currentProgram] ) {
        NSTimeInterval startOfProgram = [[[[SessionManager shared] currentProgram] soft_starts_at] timeIntervalSince1970];
        return current - startOfProgram;
    }
    
    return (NSTimeInterval)0;

}

- (BOOL)uiIsJogging {
    if ( [self.liveDescriptionLabel.text isEqualToString:kRewindingText] ) return YES;
    if ( [self.liveDescriptionLabel.text isEqualToString:kForwardingText] ) return YES;
    return NO;
}

-(void)skipBackwardEvent: (MPSkipIntervalCommandEvent *)skipEvent {
    [self rewindFifteen];
}

-(void)skipForwardEvent: (MPSkipIntervalCommandEvent *)skipEvent {
    [self fastForwardFifteen];
}

- (IBAction)backToLiveTapped:(id)sender {
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [self activateFastForward];
    }];
}

- (IBAction)shareButtonTapped:(id)sender {
    if (self.onDemandProgram && self.onDemandEpUrl) {
        UIActivityViewController *controller = [[UIActivityViewController alloc]
                                                initWithActivityItems:@[self.onDemandEpUrl]
                                                applicationActivities:nil];
        controller.excludedActivityTypes = @[UIActivityTypeAirDrop];
        [self presentViewController:controller animated:YES completion:nil];
    }
}

- (IBAction)showPreRollTapped:(id)sender {
    [self cloakForPreRoll:YES];
    [self.preRollViewController showPreRollWithAnimation:YES completion:^(BOOL done) {

    }];
}

# pragma mark - Audio commands
- (void)playStream {
    [[AudioManager shared] startStream];
    [self primeManualControlButton];
}

- (void)pauseStream {
    [[AudioManager shared] pauseStream];
    [self primeManualControlButton];
}

- (void)rewindFifteen {
    seekRequested = YES;
    [[AudioManager shared] backwardSeekFifteenSeconds];
}

- (void)fastForwardFifteen {
    seekRequested = YES;
    [[AudioManager shared] forwardSeekFifteenSeconds];
}

- (void)updateDataForUI {
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [self.liveProgressViewController displayWithProgram:(Program*)returnedObject
                                                onView:self.view
                                    aboveSiblingView:self.playerControlsView];
        [self.liveProgressViewController hide];
    }];
}

- (void)goLive {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) return;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"audio_player_began_playing"
                                                  object:nil];
    [self.jogShuttle endAnimations];
    
    [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
        [self setLiveStreamingUI:YES];
        [self treatUIforProgram];
        [self primePlaybackUI:YES];
        [self decloakForMenu:YES];
        [[AudioManager shared] playLiveStream];
    }];
    
}

- (void)activateRewind:(RewindDistance)distance {
    [self snapJogWheel];
    [self.liveDescriptionLabel pulsate:kRewindingText color:nil];
    
    self.jogging = YES;
    self.rewindGate = YES;
    
    // Disable this until the stream separates from the beginning
    // of the program a litle bit
    // self.liveRewindAltButton.userInteractionEnabled = NO;
    // [self.liveRewindAltButton setAlpha:kDisabledAlpha];
    
    Program *cProgram = [[SessionManager shared] currentProgram];
    [self.jogShuttle.view setAlpha:1.0];
    [self.liveProgressViewController rewind];
    
    [self.jogShuttle animateWithSpeed:1.0
                         hideableView:self.playPauseButton
                            direction:SpinDirectionBackward
                            withSound:YES
                           completion:^{
                               
                               [[AudioManager shared].audioPlayer.currentItem cancelPendingSeeks];
                               [self.liveDescriptionLabel stopPulsating];
                               self.jogging = NO;
                               self.dirtyFromRewind = YES;
                               [self updateControlsAndUI:YES];
                               seekRequested = NO;
                               setPlaying = YES;
                               [[SessionManager shared] invalidateSession];
                               
                               [[AudioManager shared] adjustAudioWithValue:0.1 completion:^{
                                   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                       self.rewindGate = NO;
                                   });
                               }];
                               
                               
                           }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        seekRequested = YES;
        switch (distance) {
            case RewindDistanceBeginning:
                if (cProgram) {
                    if ( self.dirtyFromRewind ) {
                        [[AudioManager shared] specialSeekToDate:cProgram.soft_starts_at];
                    } else {
                        [[AudioManager shared] seekToDate:cProgram.soft_starts_at];
                    }
                }
                break;
            case RewindDistanceFifteen:
                [self rewindFifteen];
                break;
            case RewindDistanceThirty:
            default:
                break;
        }
        
        
    });
    
}

- (void)activateFastForward {
    [self snapJogWheel];
    
    if ( !setForOnDemandUI ) {
        self.jogging = YES;
        [self.liveDescriptionLabel pulsate:kForwardingText color:nil];
    }
    
    [self.jogShuttle.view setAlpha:1.0];
    
    [self.liveProgressViewController forward];
    
    [self.jogShuttle animateWithSpeed:0.66
                         hideableView:self.playPauseButton
                            direction:SpinDirectionForward
                            withSound:NO
                           completion:^{
                               
                               [self.liveDescriptionLabel stopPulsating];
                               self.jogging = NO;
                               self.dirtyFromRewind = NO;
                               [self updateControlsAndUI:YES];
                               if ( !setPlaying ) {
                                   seekRequested = NO;
                                   setPlaying = YES;
                               }
                               
                               [[SessionManager shared] invalidateSession];
                               
                               [[AudioManager shared] adjustAudioWithValue:0.1 completion:^{
                                   [self.view bringSubviewToFront:self.playerControlsView];
                               }];
                           }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.66 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        seekRequested = YES;
        [[AudioManager shared] forwardSeekLive];
        
    });
}



# pragma mark - UI control
- (void)moveTextIntoPlace:(BOOL)animated {
    
    CGFloat constant = 40;
    if ( self.programTitleYConstraint.constant == constant ) return;
    if ( !animated ) {
        [self.programTitleYConstraint setConstant:constant];
    } else {
        
        POPSpringAnimation *programTitleAnim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
        programTitleAnim.toValue = @(constant);
        [self.programTitleYConstraint pop_addAnimation:programTitleAnim forKey:@"animateProgramTitleDown"];

    }
    
}

- (void)updateControlsAndUI:(BOOL)animated {

    // First set contents of background, live-status labels, and play button.
    [self setUIContents:animated];

    // Set positioning of UI elements.
    [self setUIPositioning];
}

- (void)setUIContents:(BOOL)animated {

    if ( self.jogging || self.queueBlurShown ) {
        return;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.1 animations:^{
            //[self.playPauseButton setAlpha:0.0];

            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                if ( ![self uiIsJogging] ) {
                    [self.liveDescriptionLabel fadeText:@"LIVE"];
                }
                [self.rewindToShowStartButton setAlpha:0.0];
            } else {
                if ( ![self.liveDescriptionLabel.text isEqualToString:@"LIVE"] ) {
                    [self.liveDescriptionLabel fadeText:@"ON NOW"];
                }

                [self.backToLiveButton setAlpha:0.0];
            }

        } completion:^(BOOL finished) {
            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
            } else {
                [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_play.png"] duration:0.2];
            }

            // Leave this out for now.
            // [self scaleBackgroundImage];
        
            [UIView animateWithDuration:0.1 animations:^{
                [self.playPauseButton setAlpha:1.0];
                [self.jogShuttle.view setAlpha:0.0];
            }];
            
        }];

    } else {
        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            if ( ![self uiIsJogging] ) {
                [self.liveDescriptionLabel fadeText:@"LIVE"];
            }
            [self.rewindToShowStartButton setAlpha:0.0];
        } else {
            if ( ![self.liveDescriptionLabel.text isEqualToString:@"LIVE"] ) {
                [self.liveDescriptionLabel fadeText:@"ON NOW"];
            }
            [self.backToLiveButton setAlpha:0.0];
        }

        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
        } else {
            [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
        }
    }
}

- (void)setUIPositioning {

    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {

        POPBasicAnimation *genericFadeInAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        genericFadeInAnim.toValue = @(1);
        [self.backToLiveButton.layer pop_addAnimation:genericFadeInAnim forKey:@"backToLiveFadeInAnim"];

        POPBasicAnimation *genericFadeOutAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        genericFadeOutAnim.toValue = @(0);
        [self.rewindToShowStartButton.layer pop_addAnimation:genericFadeOutAnim forKey:@"rewindToStartFadeInAnim"];
        
    } else {
        if (!setPlaying) {
            if (!initialPlay) {
                POPBasicAnimation *genericFadeInAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
                genericFadeInAnim.toValue = @(1);
                [self.rewindToShowStartButton.layer pop_addAnimation:genericFadeInAnim forKey:@"rewindToStartFadeInAnim"];
            }
        }
    }
}


/**
 * Dev note: Not being called for now.. zooms in background program image slightly
 */
- (void)scaleBackgroundImage {
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];

    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
        scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
        scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
    } else {
        scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
        scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    }

    scaleAnimation.springBounciness = 2.0f;
    scaleAnimation.springSpeed = 2.0f;

    // Used to ensure animation only gets started once.
    // This method stems from onRateChange: firing, which sometimes gets called rapidly.
    [scaleAnimation setCompletionBlock:^(POPAnimation *animation, BOOL done) {
        busyZoomAnim = NO;
    }];

    if (!seekRequested && !busyZoomAnim) {
        busyZoomAnim = YES;
        [self.programImageView.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
    }
}

- (void)setLiveStreamingUI:(BOOL)animated {
    
    setForOnDemandUI = NO;
    setForLiveStreamUI = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:@"audio_player_began_playing"
                                               object:nil];
    
    self.navigationItem.title = @"KPCC Live";
    [self primeRemoteCommandCenter:YES];

    if ([self.liveStreamView isHidden]) {
        [self.liveStreamView setHidden:NO];
    }

    if (![self.onDemandPlayerView isHidden]) {
        [self.onDemandPlayerView setHidden:YES];
        setForOnDemandUI = NO;
    }

    if (![self.timeLabelOnDemand isHidden]) {
        [self.timeLabelOnDemand setHidden:YES];
    }

    if (![self.progressView isHidden]) {
        [self.progressView setHidden:YES];
    }
    
    if (![self.queueScrollView isHidden]) {
        [self.queueScrollView setHidden:YES];
    }

    setForLiveStreamUI = YES;
    //self.horizDividerLine.alpha = 0.0;
    
    [self moveTextIntoPlace:NO];
    [[AudioManager shared] setCurrentAudioMode:AudioModeLive];
    [self.liveProgressViewController show];
}

- (void)setOnDemandUI:(BOOL)animated forProgram:(Program*)program withAudio:(NSArray*)array atCurrentIndex:(int)index {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rebootOnDemandUI)
                                                 name:@"audio_player_began_playing"
                                               object:nil];
    
    setForOnDemandUI = YES;
    setForLiveStreamUI = NO;
    
    if (self.menuOpen) {
        [self decloakForMenu:NO];
    }

    
    [[SessionManager shared] setCurrentProgram:nil];
    [self.liveProgressViewController hide];
    
    
    self.navigationItem.title = @"Programs";
    [self.timeLabelOnDemand setText:@""];
    [self.progressView setProgress:0.0 animated:YES];
    self.progressView.alpha = 1.0;
    self.queueScrollView.alpha = 1.0;
    self.onDemandPlayerView.alpha = 1.0;

    [self primeRemoteCommandCenter:NO];

    // Make sure the larger play button is hidden ...
    [self primePlaybackUI:NO];
    
    initialPlay = YES;

    for (UIView *v in [self.queueScrollView subviews]) {
        [v removeFromSuperview];
    }
    self.queueContents = array;
    for (int i = 0; i < [array count]; i++) {
        CGRect frame;
        frame.origin.x = self.queueScrollView.frame.size.width * i;
        frame.origin.y = 0;
        frame.size = self.queueScrollView.frame.size;

        SCPRQueueScrollableView *queueSubView = [[SCPRQueueScrollableView alloc] initWithFrame:frame];
        [queueSubView setAudioChunk:array[i]];

        [self.queueScrollView addSubview:queueSubView];
    }
    self.queueScrollView.contentSize = CGSizeMake(self.queueScrollView.frame.size.width * [array count], self.queueScrollView.frame.size.height);
    [self setPositionForQueue:index animated:NO];
    [self.queueScrollView setHidden:NO];

    [self setDataForOnDemand:program andAudioChunk:array[index]];

    if ([self.onDemandPlayerView isHidden]) {
        [self.onDemandPlayerView setHidden:NO];
    }

    if (![self.liveStreamView isHidden]) {
        [self.liveStreamView setHidden:YES];
        setForLiveStreamUI = NO;
    }

    if ([self.timeLabelOnDemand isHidden]) {
        [self.timeLabelOnDemand setHidden:NO];
    }

    if ([self.progressView isHidden]) {
        [self.progressView setHidden:NO];
    }

    [[AudioManager shared] setCurrentAudioMode:AudioModeOnDemand];
}

- (void)setDataForOnDemand:(Program *)program andAudioChunk:(AudioChunk*)audioChunk {
    if (program != nil) {
        self.onDemandProgram = program;

        [[AudioManager shared] updateNowPlayingInfoWithAudio:audioChunk];
        [[DesignManager shared] loadProgramImage:program.program_slug
                                    andImageView:self.programImageView
                                      completion:^(BOOL status) {
                                          [self.blurView setNeedsDisplay];
                                          [self.queueBlurView setNeedsDisplay];
                                      }];

        [self.programTitleOnDemand setText:[program.title uppercaseString]];
    }
}

- (void)setPositionForQueue:(int)index animated:(BOOL)animated {
    if (index >= 0 && index < [self.queueScrollView.subviews count]) {
        if (animated) {
            [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                self.queueScrollView.contentOffset = CGPointMake(self.queueScrollView.frame.size.width * index, 0);
            } completion:^(BOOL finished) {
                [self rebootOnDemandUI];
                self.queueCurrentPage = index;
            }];
        } else {
            self.queueScrollView.contentOffset = CGPointMake(self.queueScrollView.frame.size.width * index, 0);
            [self rebootOnDemandUI];
            self.queueCurrentPage = index;
        }
    }
    [self.queueScrollView layoutIfNeeded];
}

- (void)treatUIforProgram {
    Program *programObj = [[SessionManager shared] currentProgram];
    // Only update background image when we're not in On Demand mode.
    if (!setForOnDemandUI){
        [[DesignManager shared] loadProgramImage:programObj.program_slug
                                    andImageView:self.programImageView
                                      completion:^(BOOL status) {
                                          
                                          [self.blurView setNeedsDisplay];
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              [self updateUIWithProgram:programObj];
                                              [[AudioManager shared] updateNowPlayingInfoWithAudio:programObj];
                                              self.navigationController.navigationBarHidden = NO;
                                              
                                              [self.view layoutIfNeeded];
                                              [self.initialControlsView layoutIfNeeded];
                                              
                                              self.view.alpha = 1.0;
                                              if ( [SCPRCloakViewController cloakInUse] ) {
                                                  [SCPRCloakViewController uncloak];
                                              }
                                          });
                                          
                                      }];
    } else {
    
        [self updateUIWithProgram:programObj];
        self.view.alpha = 1.0;
        
    }
    
}

- (void)updateUIWithProgram:(Program*)program {
    if (!program) {
        return;
    }

    if ([program title]) {
        if ([program title].length <= 14) {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:46.0]];
        } else if ([program title].length > 14 && [program title].length <= 18) {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:35.0]];
        } else {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:30.0]];
        }
        [self.programTitleLabel setText:[program title]];
    }
}

- (void)primePlaybackUI:(BOOL)animated {

    if (animated) {
        
        [UIView animateWithDuration:0.25 animations:^{
            self.initialControlsView.alpha = 0.0;
        } completion:^(BOOL finished) {
            POPSpringAnimation *bottomAnim = [POPSpringAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
            bottomAnim.toValue = @(60);
            [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animatePlayControlsDown"];
            
            self.horizDividerLine.layer.transform = CATransform3DMakeScale(0.025f, 1.0f, 1.0f);
            self.horizDividerLine.layer.opacity = 0.4;
            POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
            scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.025f, 1.0f)];
            scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
            [scaleAnimation setCompletionBlock:^(POPAnimation *p, BOOL c) {
                self.initialPlay = YES;
                if ( !self.preRollViewController.tritonAd ) {
                    [self playStream];
                }
                
                [self.liveProgressViewController show];
            }];
            [self.horizDividerLine.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
        }];
        
    } else {
        self.initialPlayButton.alpha = 0.0;
        self.initialControlsView.hidden = YES;
        [self.playerControlsBottomYConstraint setConstant:60];
    }
}

- (void)primeManualControlButton {
    
    Program *program = [[SessionManager shared] currentProgram];
    NSDate *currentDate = [AudioManager shared].audioPlayer.currentItem.currentDate;
    NSTimeInterval current = [currentDate timeIntervalSince1970];
    NSTimeInterval beginning = [program.soft_starts_at timeIntervalSince1970];
    
    BOOL okToShow = ( ( current - beginning > 90 )
                     && [[AudioManager shared] status] == StreamStatusPaused &&
                     [[AudioManager shared] currentAudioMode] == AudioModeLive);
 
    [self.liveRewindAltButton removeTarget:nil
                                    action:nil
                          forControlEvents:UIControlEventAllEvents];
    
    if ( [[SessionManager shared] sessionIsBehindLive] ) {
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_back_to_live_xtra-small.png"]
                                      forState:UIControlStateHighlighted];
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_back_to_live_xtra-small.png"]
                                      forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Rewind to the start of this show"
                                  forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Rewind to the start of this show"
                                  forState:UIControlStateHighlighted];
    } else {
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_live_rewind_xtra-small.png"]
                                  forState:UIControlStateHighlighted];
        [self.liveRewindAltButton setImage:[UIImage imageNamed:@"btn_live_rewind_xtra-small.png"]
                                  forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Back to Live"
                                  forState:UIControlStateNormal];
        [self.liveRewindAltButton setTitle:@"Back to Live"
                                  forState:UIControlStateHighlighted];
    }
    
    if ( okToShow ) {
        [UIView animateWithDuration:0.33 animations:^{
            self.liveRewindAltButton.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.33 animations:^{
            self.liveRewindAltButton.alpha = 0.0;
        }];
    }
    
}

#pragma mark - Util



#pragma mark - Menu control

- (void)cloakForMenu:(BOOL)animated {
    [self removeAllAnimations];
    
    [self.liveProgressViewController hide];
    
    self.navigationItem.title = @"Menu";
    
    [self.blurView setNeedsDisplay];

    if (animated) {
        [pulldownMenu openDropDown:YES];
    } else {
        [pulldownMenu openDropDown:NO];
    }

    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @0;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
        [self.queueScrollView.layer pop_addAnimation:onDemandElementsFade forKey:@"queueScrollViewFadeAnimation"];
    }

    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.35;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];
    if (!initialPlay) {
        [self.initialControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"initialControlsViewFade"];
    }

    
    POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    dividerFadeAnim.toValue = @0;
    dividerFadeAnim.duration = 0.3;
    [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerOutFadeAnimation"];
    
    
    self.menuOpen = YES;
}

- (void)decloakForMenu:(BOOL)animated {
    [self removeAllAnimations];

    if (setForOnDemandUI) {
        self.navigationItem.title = @"Programs";
    } else {
        self.navigationItem.title = @"KPCC Live";
    }

    [self.blurView setNeedsDisplay];

    if (animated) {
        [pulldownMenu closeDropDown:YES];
    } else {
        [pulldownMenu closeDropDown:NO];
    }

    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @1;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
        [self.queueScrollView.layer pop_addAnimation:onDemandElementsFade forKey:@"queueScrollViewFadeInAnimation"];
    }

    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeIn = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeIn.toValue = @1;
    controlsFadeIn.duration = 0.3;

    [self.blurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeIn forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeIn forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeIn forKey:@"liveStreamViewFadeAnimation"];
    if (!initialPlay) {
        [self.initialControlsView.layer pop_addAnimation:controlsFadeIn forKey:@"initialControlsViewFade"];
    }

    if (setForOnDemandUI) {
        
        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @0.4;
        dividerFadeAnim.duration = 0.3;
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerFadeOutAnimation"];
        
    }

    self.menuOpen = NO;
}

- (void)removeAllAnimations {
    [self.blurView.layer pop_removeAllAnimations];
    [self.darkBgView.layer pop_removeAllAnimations];
    [self.playerControlsView.layer pop_removeAllAnimations];
    [self.onDemandPlayerView.layer pop_removeAllAnimations];
    [self.liveStreamView.layer pop_removeAllAnimations];
    [self.horizDividerLine.layer pop_removeAllAnimations];
    [self.timeLabelOnDemand.layer pop_removeAllAnimations];
    [self.progressView.layer pop_removeAllAnimations];
    [self.queueScrollView.layer pop_removeAllAnimations];
}


# pragma mark - PreRoll Control

- (void)cloakForPreRoll:(BOOL)animated {
    [self removeAllAnimations];
    [self.blurView setNeedsDisplay];

    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @0;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
    } else {
        [self.liveProgressViewController hide];
    }

    if (!initialPlay) {
        [self primePlaybackUI:YES];
    }

    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.35;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    //[self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];

    self.preRollOpen = YES;
}

- (void)decloakForPreRoll:(BOOL)animated {
    [self removeAllAnimations];

    [self.blurView setNeedsDisplay];

    if (setForOnDemandUI){
        POPBasicAnimation *onDemandElementsFade = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        onDemandElementsFade.toValue = @1;
        onDemandElementsFade.duration = 0.3;
        [self.timeLabelOnDemand.layer pop_addAnimation:onDemandElementsFade forKey:@"timeLabelFadeAnimation"];
        [self.progressView.layer pop_addAnimation:onDemandElementsFade forKey:@"progressBarFadeAnimation"];
    }

    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @1;
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];

    
    if ([[AudioManager shared] isStreamPlaying]) {
        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @0.4;
        dividerFadeAnim.duration = 0.3;
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerFadeOutAnimation"];
    }
     
    
    self.preRollOpen = NO;
}

# pragma mark - SCPRPreRollControllerDelegate

- (void)preRollCompleted {
    if (self.preRollOpen) {
        [self decloakForPreRoll:YES];
    }
    
    [[AudioManager shared] playLiveStream];
}


#pragma mark - UIScrollViewDelegate for audio queue
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {

    int newPage = scrollView.contentOffset.x / scrollView.frame.size.width;
    if (self.queueCurrentPage == newPage) {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
            self.timeLabelOnDemand.alpha = 1.0;
            self.progressView.alpha = 1.0;
            self.queueBlurView.alpha = 0.0;
            self.queueDarkBgView.alpha = 0.0;
            self.shareButton.alpha = 1.0;
        } completion:^(BOOL finished) {
            self.queueBlurShown = NO;
            

        }];
    }

    if (self.queueScrollTimer != nil && [self.queueScrollTimer isValid]) {
        [self.queueScrollTimer invalidate];
        self.queueScrollTimer = nil;
    }

    if ( [[AudioManager shared] status] == StreamStatusPlaying ) {
        if ( ![self.jogShuttle spinning] ) {
            [self snapJogWheel];

        }
    }
    
    self.queueScrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(queueScrollEnded)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.timeLabelOnDemand.alpha = 0.0;
        self.progressView.alpha = 0.0;
        self.shareButton.alpha = 0.0;
    } completion:^(BOOL finished){

    }];

    if (!self.queueBlurShown) {
        [self.queueBlurView setNeedsDisplay];
        [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            self.queueBlurView.alpha = 1.0;
            self.queueDarkBgView.alpha = 0.35;
        } completion:^(BOOL finished) {
            self.queueBlurShown = YES;
        }];
    }
}

- (void)queueScrollEnded {
    
    [self.jogShuttle animateIndefinitelyWithViewToHide:self.playPauseButton completion:^{
        self.playPauseButton.alpha = 1.0;
        self.playPauseButton.enabled = YES;
    }];
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.timeLabelOnDemand.alpha = 1.0;
    } completion:nil];

    int newPage = self.queueScrollView.contentOffset.x / self.queueScrollView.frame.size.width;
    if ((self.queueContents)[newPage]) {
        AudioChunk *chunk = (self.queueContents)[newPage];
        self.onDemandEpUrl = chunk.contentShareUrl;
        [[AudioManager shared] updateNowPlayingInfoWithAudio:chunk];
    }

    if (self.queueCurrentPage != newPage) {
        
        self.timeLabelOnDemand.text = @"Loading...";
        self.queueLoading = YES;
        
        [[QueueManager shared] playItemAtPosition:newPage];
        self.queueCurrentPage = newPage;
     
    } else {
        [self rebootOnDemandUI];
    }
}

- (void)rebootOnDemandUI {
    
    if (self.queueBlurShown) {
        [self.queueBlurView setNeedsDisplay];
        [self.jogShuttle endAnimations];

        [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            
            self.queueBlurView.alpha = 0.0;
            self.queueDarkBgView.alpha = 0.0;
            self.progressView.alpha = 1.0;
            self.shareButton.alpha = 1.0;
            
            
        } completion:^(BOOL finished) {
            self.queueBlurShown = NO;
            
        }];
        
    } else {
        [self.jogShuttle endAnimations];
    }
    self.playPauseButton.userInteractionEnabled = YES;
}

# pragma mark - PulldownMenuDelegate

- (void)menuItemSelected:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:{
            
            [self goLive];
            break;
        }

        case 1: {
            Program *prog = [[SessionManager shared] currentProgram];
            if (setForOnDemandUI && self.onDemandProgram != nil) {
                prog = self.onDemandProgram;
            }

            SCPRProgramsListViewController *vc = [[SCPRProgramsListViewController alloc] initWithBackgroundProgram:prog];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
            
        case 2: {
            
            SCPRShortListViewController *slVC = [[SCPRShortListViewController alloc] initWithNibName:@"SCPRShortListViewController"
                                                                                              bundle:nil];
            [self.navigationController pushViewController:slVC animated:YES];
            break;
            
        }
            
        case 3: {
            
            SCPRFeedbackViewController *fbVC = [[SCPRFeedbackViewController alloc] initWithNibName:@"SCPRFeedbackViewController"
                                                                                            bundle:nil];
            [self.navigationController pushViewController:fbVC animated:YES];
            break;
            
        }
        default: {
            [self decloakForMenu:YES];
            break;
        }
    }
}

- (void)pullDownAnimated:(BOOL)open {
    // Notifications used in SCPRNavigationController.
    if (open) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_opened"
                                                            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_closed"
                                                            object:nil];
    }
}


# pragma mark - AudioManagerDelegate

- (void)onRateChange {
    [self updateControlsAndUI:YES];
}

- (void)onTimeChange {
    
    if ( self.jogging ) {
        return;
    }
    
#ifdef DEBUG
    if ( [[SessionManager shared] ignoreProgramUpdating] ) {
        //NSLog(@" **** App is ignoring program updates *** ");
    }
#endif
    
    NSAssert([NSThread isMainThread],@"This is not the main thread...");
    NSTimeInterval ti = [[[AudioManager shared] maxSeekableDate] timeIntervalSinceDate:[[AudioManager shared] currentDate]];
    
    Program *program = [[SessionManager shared] currentProgram];
    if ( program ) {
        [self.liveProgressViewController tick];
    }
  
    
    if ( ti > 60 && ![[AudioManager shared] isStreamBuffering] ) {
        
        
        [self.liveDescriptionLabel fadeText:[NSString stringWithFormat:@"%@ BEHIND LIVE", [NSDate prettyTextFromSeconds:ti]]];
        [self.backToLiveButton setHidden:NO];
        

    } else {
        [self.liveDescriptionLabel fadeText:@"LIVE"];
        [self.backToLiveButton setHidden:YES];
        self.dirtyFromRewind = NO;
        
    }

    if (setForOnDemandUI) {
        [self.progressView pop_removeAllAnimations];

        if (CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration]) > 0) {
            double currentTime = CMTimeGetSeconds([[[AudioManager shared] playerItem] currentTime]);
            double duration = CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration]);

            [self.timeLabelOnDemand setText:[Utils elapsedTimeStringWithPosition:currentTime
                                                                     andDuration:duration]];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.progressView setProgress:(currentTime / duration) animated:YES];
            });
        }
    } else {
        if ( !self.menuOpen ) {
            if ( self.initialPlay ) {
                [self.liveProgressViewController show];
            }
        }
    }
    


    
    // NOTE: basically used instead of observing player rate change to know when actual playback starts
    // .. for decloaking queue blur
    if (self.queueBlurShown && self.queueLoading) {
        [self.queueBlurView setNeedsDisplay];
        [self.progressView setProgress:0.0 animated:NO];
        [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionCurveLinear animations:^{
            self.queueBlurView.alpha = 0.0;
            self.queueDarkBgView.alpha = 0.0;
            self.progressView.alpha = 1.0;
            self.shareButton.alpha = 1.0;
        } completion:^(BOOL finished) {
            self.queueBlurShown = NO;
            self.queueLoading = NO;
        }];
    }
    
}

- (void)onSeekCompleted {
    // Make sure UI gets set to "Playing" state after a seek.
    if ( self.jogging ) {
        [self.jogShuttle endAnimations];
    } else {
        if (!setPlaying) {
            seekRequested = NO;            
            [self setUIPositioning];
            setPlaying = YES;
        }
    }
}


#pragma mark - ContentProcessor

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
/*    if ([content count] == 0) {
        return;
    }

    // Create Program and insert into managed object context
    if ([content objectAtIndex:0]) {
        NSDictionary *programDict = [content objectAtIndex:0];

        Program *programObj = [Program insertProgramWithDictionary:programDict inManagedObjectContext:[[ContentManager shared] managedObjectContext]];

        // Only update background image when we're not in On Demand mode.
        if (!setForOnDemandUI){
            [[DesignManager shared] loadProgramImage:programObj.program_slug
                                        andImageView:self.programImageView
                                          completion:^(BOOL status) {
                                              [self.blurView setNeedsDisplay];
                                              [self.queueBlurView setNeedsDisplay];
                                          }];
        }

        [self updateUIWithProgram:programObj];

        if (!setForOnDemandUI) {
            [[AudioManager shared] updateNowPlayingInfoWithAudio:programObj];
        }

        self.currentProgram = programObj;

        // Save any programObj changes to CoreData.
        [[ContentManager shared] saveContext];
    }
 */
}

- (void)dealloc {
    //End receiving events.
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)primeRemoteCommandCenter:(BOOL)forLiveStream {
    MPRemoteCommandCenter *rcc = [MPRemoteCommandCenter sharedCommandCenter];

    if (forLiveStream) {
        [[rcc previousTrackCommand] setEnabled:NO];
        MPSkipIntervalCommand *skipBackwardIntervalCommand = [rcc skipBackwardCommand];
        [skipBackwardIntervalCommand setEnabled:YES];
        [skipBackwardIntervalCommand addTarget:self action:@selector(skipBackwardEvent:)];
        skipBackwardIntervalCommand.preferredIntervals = @[@(15)];

        [[rcc nextTrackCommand] setEnabled:NO];
        MPSkipIntervalCommand *skipForwardIntervalCommand = [rcc skipForwardCommand];
        skipForwardIntervalCommand.preferredIntervals = @[@(15)];  // Max 99
        [skipForwardIntervalCommand setEnabled:YES];
        [skipForwardIntervalCommand addTarget:self action:@selector(skipForwardEvent:)];
    } else {
        [[rcc skipBackwardCommand] setEnabled:NO];
        MPRemoteCommand *prevTrackCommand = [rcc previousTrackCommand];
        [prevTrackCommand addTarget:self action:@selector(prevEpisodeTapped:)];
        [prevTrackCommand setEnabled:YES];

        [[rcc skipForwardCommand] setEnabled:NO];
        MPRemoteCommand *nextTrackCommand = [rcc nextTrackCommand];
        [nextTrackCommand addTarget:self action:@selector(nextEpisodeTapped:)];
        [nextTrackCommand setEnabled:YES];
    }

    MPRemoteCommand *pauseCommand = [rcc pauseCommand];
    [pauseCommand setEnabled:YES];
    [pauseCommand addTarget:self action:@selector(pauseTapped:)];

    MPRemoteCommand *playCommand = [rcc playCommand];
    [playCommand setEnabled:YES];
    [playCommand addTarget:self action:@selector(playTapped:)];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
