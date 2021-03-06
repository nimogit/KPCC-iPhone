//
//  SCPRProgressViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgressViewController.h"
#import "Utils.h"
#import "AudioManager.h"
#import "SessionManager.h"
#import <pop/POP.h>
#import "SCPRMasterViewController.h"

@interface SCPRProgressViewController ()

- (void)finishReveal;

@end

@implementation SCPRProgressViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
}

+ (SCPRProgressViewController*)o {
    static SCPRProgressViewController *pv = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pv = [[SCPRProgressViewController alloc] initWithNibName:@"SCPRProgressViewController"
                                                          bundle:nil];
    });
    return pv;
}

- (void)viewDidLayoutSubviews {
    [self.liveProgressView setNeedsDisplay];
    [self.currentProgressView setNeedsDisplay];
    [self.liveProgressView setNeedsUpdateConstraints];
    [self.currentProgressView setNeedsUpdateConstraints];
}

- (void)displayWithProgram:(ScheduleOccurrence*)program onView:(UIView *)view aboveSiblingView:(UIView *)anchorView {
    
    [self setupProgressBarsWithProgram:program];
    if ( self.view.superview ) {
        if ( self.liveBarLine || self.currentBarLine ) {
            return;
        }
    }
    
    self.view.backgroundColor = [UIColor clearColor];
    self.view.clipsToBounds = YES;
    CGFloat width = self.view.frame.size.width;
    
    self.barWidth = width;
    self.liveBarLine = [CAShapeLayer layer];
    self.currentBarLine = [CAShapeLayer layer];
    
    CGMutablePathRef liveLinePath = CGPathCreateMutable();
    
    CGPoint pts[2];
    pts[0] = CGPointMake(0.0, 0.0);
    pts[1] = CGPointMake(width, 0.0);
    CGPathAddLines(liveLinePath, nil, pts, 2);
    
    CGMutablePathRef currentLinePath = CGPathCreateMutable();
    self.liveBarLine.path = liveLinePath;
    CGPathRelease(liveLinePath);
    
    self.liveBarLine.strokeColor = self.liveTintColor.CGColor;
    self.liveBarLine.strokeStart = 0.0f;
    self.liveBarLine.strokeEnd = 0.0f;
    self.liveBarLine.opacity = 1.0f;
    self.liveBarLine.fillColor = self.liveTintColor.CGColor;
    self.liveBarLine.lineWidth = self.view.frame.size.height*2.0f;
    
    CGPoint lPts[2];
    lPts[0] = CGPointMake(0.0, 0.0);
    lPts[1] = CGPointMake(width, 0.0);
    CGPathAddLines(currentLinePath, nil, lPts, 2);
    
    self.currentBarLine.path = currentLinePath;
    CGPathRelease(currentLinePath);
    
    self.currentBarLine.strokeColor = self.currentTintColor.CGColor;
    self.currentBarLine.strokeStart = 0.0f;
    self.currentBarLine.strokeEnd = 0.0f;
    self.currentBarLine.opacity = 1.0f;
    self.currentBarLine.fillColor = self.currentTintColor.CGColor;
    self.currentBarLine.lineWidth = self.view.frame.size.height*2.0f;
    
    [self.liveProgressView.layer addSublayer:self.liveBarLine];
    [self.currentProgressView.layer addSublayer:self.currentBarLine];
    
    [self.liveProgressView layoutIfNeeded];
    [self.currentProgressView layoutIfNeeded];
    [self hide];
    
    //self.currentProgressView.backgroundColor = [UIColor greenColor];
    //self.liveProgressView.backgroundColor = [UIColor blueColor];
    
    
    [self.view layoutIfNeeded];
    
}

- (void)setupProgressBarsWithProgram:(ScheduleOccurrence *)program {
    
    self.currentProgram = program;
    self.liveTintColor = [[UIColor virtualWhiteColor] translucify:0.33];
    self.liveProgressView.backgroundColor = [UIColor clearColor];
    self.currentTintColor = [UIColor kpccOrangeColor];
    self.currentProgressView.backgroundColor = [UIColor clearColor];
    self.lastLiveValue = 0.0f;
    self.lastCurrentValue = 0.0f;
    self.liveProgressView.clipsToBounds = YES;
    self.currentProgressView.clipsToBounds = YES;
    self.currentProgressView.alpha = 0.0f;
    self.liveProgressView.alpha = 0.0f;
    self.uiHidden = YES;
    self.view.alpha = 0.0f;
    self.view.backgroundColor = [UIColor clearColor];
}

- (void)hide {
    [UIView animateWithDuration:0.25 animations:^{
        [self.view setAlpha:0.0];
    } completion:^(BOOL finished) {
        self.uiHidden = YES;
    }];
}

- (void)show {
    [self show:NO];
}

- (void)show:(BOOL)force {
    
    if ( !force ) {
        if ( !self.uiHidden ) return;
    }
    
    
    if ( [[[AudioManager shared] status] status] == AudioStatusStopped ) return;
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
    
    // An ugly and absurd opacity check that at this point seems necessary
    if ( self.view.alpha == 1.0 &&
        self.view.layer.opacity == 1.0 &&
        self.liveProgressView.alpha == 1.0 &&
        self.liveProgressView.layer.opacity == 1.0 &&
        self.currentProgressView.alpha == 1.0 &&
        self.currentProgressView.layer.opacity == 1.0 ) {
        return;
    }
  
    self.uiHidden = NO;
    

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            self.view.layer.opacity = 1.0f;
            [self.view setAlpha:1.0];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.25 animations:^{
                self.liveProgressView.alpha = 1.0f;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.25 animations:^{
                    self.currentProgressView.alpha = 1.0f;
                } completion:^(BOOL finished) {
                    
                }];
            }];
        }];
    });

}

- (void)rewind {
    
    @synchronized(self) {
        self.shuttling = YES;
    }
    
#ifdef DONT_USE_LATENCY_CORRECTION
    CGFloat vBeginning = 0.1;
#else
    CGFloat vBeginning = 0.0f;
#endif
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            self.lastCurrentValue = vBeginning;
            self.currentBarLine.strokeEnd = vBeginning;
            [self.currentBarLine removeAllAnimations];
            self.shuttling = NO;
        }];
        
        CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        [currentAnim setToValue:[NSNumber numberWithFloat:vBeginning]];
        [currentAnim setDuration:1.6f];
        [currentAnim setRemovedOnCompletion:NO];
        [currentAnim setFillMode:kCAFillModeForwards];
        [self.currentBarLine addAnimation:currentAnim forKey:@"decrementCurrent"];
    }
    [CATransaction commit];
}

- (void)forward {
    
    @synchronized(self) {
        self.shuttling = YES;
    }
    
    ScheduleOccurrence *program = [[SessionManager shared] currentSchedule];
    
    NSTimeInterval beginning = [program.soft_starts_at timeIntervalSince1970];
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval duration = ( end - beginning );
    NSTimeInterval live = [[[SessionManager shared] vLive] timeIntervalSince1970];
    
    CGFloat vBeginning = (live - beginning)/duration;
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            self.lastCurrentValue = vBeginning;
            self.shuttling = NO;
            self.currentBarLine.strokeEnd = vBeginning;
            [self.currentBarLine removeAllAnimations];
        }];
        CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        [currentAnim setToValue:[NSNumber numberWithFloat:vBeginning]];
        [currentAnim setDuration:1.2f];
        [currentAnim setRemovedOnCompletion:NO];
        [currentAnim setFillMode:kCAFillModeForwards];
        [self.currentBarLine addAnimation:currentAnim forKey:@"forwardCurrent"];
    }
    [CATransaction commit];
    
}

- (void)update {
    NSDictionary *p = [[SessionManager shared] onboardingAudio];
    ScheduleOccurrence *program = [[SessionManager shared] currentSchedule];

    NSDate *currentDate = [[[AudioManager shared] audioPlayer] currentDate];
    NSTimeInterval beginning = [program.soft_starts_at timeIntervalSince1970];
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        beginning = 0;
    }

    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        end = beginning + [p[@"duration"] intValue];
    }

    NSTimeInterval duration = ( end - beginning );
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        duration = [p[@"duration"] intValue];
    }


    NSTimeInterval live = [[[SessionManager shared] vLive] timeIntervalSince1970];

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        live = CMTimeGetSeconds([[[AudioManager shared] audioPlayer] currentTime]);
    }

    NSTimeInterval current = [currentDate timeIntervalSince1970];
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        current = live;
    }

    NSTimeInterval liveDiff = ( live - beginning );
    NSTimeInterval currentDiff = ( current - beginning );

    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentBarLine.strokeEnd = (currentDiff / duration)*1.0f;
        self.liveBarLine.strokeEnd = (liveDiff / duration)*1.0f;
    });
}


- (void)tick {
    if ( self.shuttling ) return;

    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
        self.throttle++;
        if ( self.throttle % kThrottlingValue != 0 ) {
            return;
        } else {
            self.throttle = 1;
        }
    }

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        [self hide];
        return;
    }
    
    [self update];
    
}

- (void)reset {
    self.counter = 0;
    self.currentBarLine.strokeEnd = 0.0f;
}

- (void)finishReveal {
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            [self.currentBarLine removeAllAnimations];
            [self.liveBarLine removeAllAnimations];
            self.firstTickFinished = YES;
        }];
        
        CABasicAnimation *currentAnimO = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [currentAnimO setToValue:@(1.0)];
        [currentAnimO setDuration:5];
        [currentAnimO setRemovedOnCompletion:NO];
        [currentAnimO setFillMode:kCAFillModeForwards];
        [currentAnimO setCumulative:YES];
        [self.currentBarLine addAnimation:currentAnimO forKey:@"fadeInCurrent"];
        
        CABasicAnimation *liveAnimO = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [liveAnimO setToValue:@(1.0)];
        [liveAnimO setDuration:5];
        [liveAnimO setRemovedOnCompletion:NO];
        [liveAnimO setFillMode:kCAFillModeForwards];
        [liveAnimO setCumulative:YES];
        [self.liveBarLine addAnimation:liveAnimO forKey:@"fadeInLive"];
    }
    [CATransaction commit];
    
}

@end
