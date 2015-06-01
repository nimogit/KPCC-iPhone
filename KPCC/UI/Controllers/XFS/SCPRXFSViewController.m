//
//  SCPRXFSViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 5/27/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRXFSViewController.h"
#import "UIColor+UICustom.h"
#import "SCPRCornerMaskView.h"
#import "SCPRAppDelegate.h"
#import "Utils.h"
#import "SCPRNavigationController.h"
#import "pop.h"
#import "SCPRMenuCell.h"
#import "UXmanager.h"
#import "SCPRMasterViewController.h"

@interface SCPRXFSViewController ()

@end

@implementation SCPRXFSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.deployButton.backgroundColor = [UIColor clearColor];
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = [UIColor clearColor];
    
    [self.leftButton addTarget:self
                        action:@selector(leftButtonTapped)
              forControlEvents:UIControlEventTouchUpInside];
    
    [self.deployButton addTarget:self
                          action:@selector(toggleDropdown)
                forControlEvents:UIControlEventTouchUpInside];
    
    [self.cancelButton addTarget:self
                          action:@selector(cancelTapped)
                forControlEvents:UIControlEventTouchUpInside];
    [self.cancelButton.titleLabel proSemiBoldFontize];
    
    [self positionChevron];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(positionChevron)
                                                 name:@"xfs-toggle"
                                               object:nil];

    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orangeInterface)
                                                 name:@"xfs-confirmation-exit"
                                               object:nil];
    
    [self orangeInterface];
    // Do any additional setup after loading the view from its nib.
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return self.isGrayInterface ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent;
}

- (void)grayInterface {
    self.isGrayInterface = YES;
    [self adjustInterface];
}

- (void)orangeInterface {
    self.isGrayInterface = NO;
    [self adjustInterface];
}

- (void)cancelTapped {
    [self orangeInterface];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"xfs-confirmation-exit"
                                                        object:nil];
    
}

- (void)adjustInterface {
    [UIView animateWithDuration:0.33f animations:^{
        self.view.backgroundColor = self.isGrayInterface ? [UIColor paleHorseColor] : [UIColor clearColor];
        self.deployButton.alpha = self.isGrayInterface ? 0.0f : 1.0f;
        self.chevronImage.alpha = self.isGrayInterface ? 0.0f : 1.0f;
        self.cancelButton.alpha = self.isGrayInterface ? 1.0f : 0.0f;
        self.dividerView.backgroundColor = [UIColor cloudColor];
        self.dividerView.alpha = self.isGrayInterface ? 1.0f : 0.0f;
        UIStatusBarStyle sbs = self.isGrayInterface ? UIStatusBarStyleDefault : UIStatusBarStyleLightContent;
        
        [[UIApplication sharedApplication] setStatusBarStyle:sbs];
        [self setNeedsStatusBarAppearanceUpdate];
    }];
}

- (void)positionChevron {
    if ( [[UXmanager shared].settings userHasSelectedXFS] ) {
        self.chevronHorizontalAnchor.constant = 64.0f;
    } else {
        self.chevronHorizontalAnchor.constant = 80.0f;
    }
    
    [self.view layoutIfNeeded];
}

- (void)toggleDropdown {
    [self controlVisibility:!self.deployed];
}

- (void)applyHeight:(CGFloat)height {
    [UIView animateWithDuration:0.35f animations:^{
        self.heightAnchor.constant = height;
        [self.view layoutIfNeeded];
    }];
}

- (void)openDropdown {
    
    [self controlVisibility:YES];
    
}

- (void)closeDropdown {
    
    [self controlVisibility:NO];
    
}

- (void)controlVisibility:(BOOL)visible {
    if ( self.deployed == visible ) return;
    
    NSNumber *x = visible ? @([Utils degreesToRadians:180.0f]) : @(0.0f);
    POPSpringAnimation *rotation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    [rotation setToValue:x];
    [rotation setSpringBounciness:1.65f];
    [rotation setSpringSpeed:.64f];
    
    [self.chevronImage.layer pop_addAnimation:rotation forKey:@"rotate"];
    self.deployed = visible;
    
    if ( self.deployed ) {
        self.leftButton.userInteractionEnabled = NO;
    } else {
        self.leftButton.userInteractionEnabled = YES;
    }
    NSString *message = visible ? @"xfs-shown" : @"xfs-hidden";
    
    [[NSNotificationCenter defaultCenter] postNotificationName:message
                                                        object:nil];
    
#ifdef OVERLAY_XFS_INTERFACE
    CGFloat h = !visible ? [[[Utils del] masterNavigationController] navigationBar].frame.size.height+20.0f : [[Utils del] window].frame.size.height;
    [self applyHeight:h];
#endif
    
}

- (void)showCoachingBalloon {
    
    self.xfsBalloon = [[SCPRBalloonViewController alloc]
                       initWithNibName:@"SCPRBalloonViewController"
                       bundle:nil];
    
    self.xfsBalloon.view = self.xfsBalloon.view;

    [self.view addSubview:self.xfsBalloon.view];
    
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.xfsBalloon.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSArray *xfsAnchors = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-56.0-[balloon(68.0)]"
                                                                  options:0
                                                                  metrics:nil
                                                                    views:@{ @"balloon" : self.xfsBalloon.view }];
    NSArray *xfsXanchors = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-6.0-[balloon]-6.0-|"
                                                                   options:0
                                                                   metrics:nil
                                                                     views:@{ @"balloon" : self.xfsBalloon.view}];
    
    [self.xfsBalloon prime];
    
    [self.view addConstraints:xfsAnchors];
    [self.view addConstraints:xfsXanchors];
    [self.view layoutIfNeeded];
    
    self.xfsBalloon.triangleHorizontalAnchor.constant = self.view.frame.size.width / 2.0 - self.xfsBalloon.triangleView.frame.size.width / 2.0f;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(coachingBalloonDismissed)
                                                 name:@"balloon-dismissed"
                                               object:nil];
    
    [self applyHeight:self.view.frame.size.height+self.xfsBalloon.view.frame.size.height-8.0f];
    
}

- (void)coachingBalloonDismissed {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.xfsBalloon = nil;
    
    SCPRAppDelegate *del = [Utils del];
    CGFloat height = [[del masterViewController].navigationController navigationBar].frame.size.height + 20.0f;
    [self applyHeight:height];
}

- (void)leftButtonTapped {
    [[[Utils del] masterNavigationController] leftButtonTapped];
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
