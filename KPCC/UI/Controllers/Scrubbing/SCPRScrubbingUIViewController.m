//
//  SCPRScrubbingUIViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRScrubbingUIViewController.h"
#import "DesignManager.h"
#import "SCPRMasterViewController.h"

@interface SCPRScrubbingUIViewController ()

@end

@implementation SCPRScrubbingUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.darkeningView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.35];
    

    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    
}

- (void)prerender {
    self.scrubberController.view.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.2];
    [self.scrubberController setup];
    
    [self.fw30Button addTarget:self
                        action:@selector(forward30)
              forControlEvents:UIControlEventTouchUpInside];
    
    [self.rw30Button addTarget:self
                        action:@selector(rewind30)
              forControlEvents:UIControlEventTouchUpInside];

}

- (void)forward30 {
    CMTime ct = [[AudioManager shared].audioPlayer.currentItem currentTime];
    ct.value += (30.0*ct.timescale);
    [[AudioManager shared].audioPlayer.currentItem seekToTime:ct];
}

- (void)rewind30 {
    CMTime ct = [[AudioManager shared].audioPlayer.currentItem currentTime];
    ct.value -= (30.0*ct.timescale);
    [[AudioManager shared].audioPlayer.currentItem seekToTime:ct];
}

- (void)setupWithProgram:(NSDictionary *)program blurredImage:(UIImage *)image parent:(id)parent {
    self.parentControlView = parent;
    self.blurredImageView.image = image;
    AudioChunk *ac = program[@"chunk"];
    
    self.captionLabel.text = ac.audioTitle;
    self.blurredImageView.alpha = 0.0;
    

    self.captionLabel.font = [[DesignManager shared] proLight:self.captionLabel.font.pointSize];
    
    [self.closeButton addTarget:self
                         action:@selector(closeScrubber)
               forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)closeScrubber {
    SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
    [UIView animateWithDuration:0.25 animations:^{
        [mvc killCloseButton];
        [mvc decloakForScrubber];
        [self.scrubberController applyMask];
        [[DesignManager shared] fauxRevealNavigationBar];
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [mvc finishedWithScrubber];
    }];
}

- (void)setCloseButton:(UIButton *)closeButton {
    _closeButton = closeButton;
    if ( closeButton ) {
        [closeButton addTarget:self
                        action:@selector(closeScrubber)
              forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)takedown {
    
    self.scrubberController.panning = NO;
    self.scrubberController.currentBarLine.strokeEnd = 0.0;
    
}

#pragma mark - AudioManager
- (void)onRateChange {
    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
    } else {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_play.png"] duration:0.2];
    }
}

- (void)onTimeChange {
    
    [self.scrubberController tick];
    
}

- (void)scrubberWillAppear {
    StreamStatus s = [[AudioManager shared] status];
    if ( s == StreamStatusPlaying ) {
        self.scrubberController.currentBarLine.strokeEnd = 0.0;
    } else {
        [self.scrubberController tick];
    }
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
