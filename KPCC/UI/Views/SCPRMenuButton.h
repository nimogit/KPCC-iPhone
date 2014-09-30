//
//  SCPRMenuButton.h
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MenuButtonDelegate
    -(void)backPressed;
    -(void)menuPressed;
@end

@interface SCPRMenuButton : UIControl

@property (nonatomic, assign) id<MenuButtonDelegate> delegate;

+ (instancetype)button;
+ (instancetype)buttonWithOrigin:(CGPoint)origin;

@property(nonatomic) BOOL showMenu;
@property(nonatomic) BOOL showBackArrow;

- (void)animateToBack;
- (void)animateToMenu;
- (void)animateToClose;

@end
