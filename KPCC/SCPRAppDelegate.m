//
//  SCPRAppDelegate.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRAppDelegate.h"
#import "SCPRMasterViewController.h"
#import "SCPRNavigationController.h"
#import "SessionManager.h"
#import "NetworkManager.h"
#import "SCPROnboardingViewController.h"
#import "UXmanager.h"
#import "AnalyticsManager.h"
#import "SCPRXFSViewController.h"
#import <Lock/Lock.h>
#import "A0FacebookAuthenticator.h"
#import "A0GoogleAuthenticator.h"

NSString *const kPushChannel = @"listenLive";

@implementation SCPRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSDictionary *globalConfig = [Utils globalConfig];
    
    [A0Theme.sharedInstance registerTheme:[A0Theme KPCCThemeWithBundle:NSBundle.mainBundle]];

    AuthenticationManager *authenticationManager = AuthenticationManager.sharedInstance;
    [authenticationManager initializeWithClientId:globalConfig[@"Auth0"][@"ClientId"]
                                           domain:globalConfig[@"Auth0"][@"Domain"]];
    NSArray *permissions = @[ @"public_profile", @"email" ];
    A0FacebookAuthenticator *facebookAuthenticator = [A0FacebookAuthenticator newAuthenticatorWithPermissions:permissions];
    A0GoogleAuthenticator *googleAuthenticator = [A0GoogleAuthenticator newAuthenticator];
    [authenticationManager.lock registerAuthenticators:@[ facebookAuthenticator, googleAuthenticator ]];
    [authenticationManager.lock applicationLaunchedWithOptions:launchOptions];

    if (UXmanager.shared.isFirstAppLaunch) {
        [authenticationManager reset];
    }

    [[AnalyticsManager shared] setup];

    [Parse setApplicationId:globalConfig[@"Parse"][@"ApplicationId"]
                  clientKey:globalConfig[@"Parse"][@"ClientKey"]];
    
#ifdef RELEASE
    [[FBSDKApplicationDelegate sharedInstance] application:application didFinishLaunchingWithOptions:launchOptions];
#endif

    // Apply application-wide styling
    [self applyStylesheet];
    
    // Initialize the window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    self.window.tintColor = [UIColor colorWithRed:49.0/255.0 green:171.0/255.0 blue:212.0/255.0 alpha:1.0];
    
    // Launch our root view controller
    SCPRNavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Storyboard" bundle:nil] instantiateInitialViewController];

    self.onboardingController = [[SCPROnboardingViewController alloc] initWithNibName:@"SCPROnboardingViewController"
                                                                               bundle:nil];
    self.onboardingController.view.frame = CGRectMake(0.0,0.0,self.window.frame.size.width,
                                                      self.window.frame.size.height);

    self.onboardingController.view.backgroundColor = [UIColor clearColor];
    
    self.masterNavigationController = navigationController;
    self.masterViewController = navigationController.viewControllers.firstObject;
    self.window.rootViewController = navigationController;
    navigationController.navigationBarHidden = YES;

    // Fetch initial list of Programs from SCPRV4 and store in CoreData for later usage.
    [[NetworkManager shared] fetchAllProgramInformation:^(id object) {
        
        //NSAssert([object isKindOfClass:[NSArray class]],@"Expecting an Array Here...");
        NSArray *content = (NSArray*)object;
        if ([content count] == 0) {
            return;
        }
        
        // Process Programs and insert into CoreData.
        NSLog(@"SCPRv4 returned %ld programs", (unsigned long)[content count]);
        [Program insertProgramsWithArray:content inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
        
        // Save all changes made.
        [[ContentManager shared] saveContext];
        
    }];
    
    // Override point for customization after application launch.
    return YES;
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    UIUserNotificationType types = notificationSettings.types;
    
    [application registerForRemoteNotifications];
    
    [[UXmanager shared] setSuppressBalloon:YES];
    [[SessionManager shared] setUseLocalNotifications:( types & UIUserNotificationTypeAlert )];
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] closeOutOnboarding];
    }
    
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"•••• FAILED REGISTERING FOR PUSH ••••");
    
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] closeOutOnboarding];
    }

    [[PFInstallation currentInstallation] removeObject:kPushChannel
                                                forKey:@"channels"];
    [[PFInstallation currentInstallation] saveInBackground];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    
    const unsigned *tokenBytes = [deviceToken bytes];
    NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                          ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                          ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                          ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
    
    [[UXmanager shared].settings setPushTokenData:deviceToken];
    [[UXmanager shared].settings setPushTokenString:hexToken];
    
    PFInstallation *i = [PFInstallation currentInstallation];

    NSLog(@" ••••• Got through to PFInstallation creation •••• ");
    

    [i setDeviceTokenFromData:deviceToken];
    [i addUniqueObject:kPushChannel
                                  forKey:@"channels"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [i saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            [[UXmanager shared] persist];
        }];
    });

    NSLog(@" ***** REGISTERING PUSH TOKEN : %@ *****", hexToken);
}


- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:userInfo
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&jsonError];
    NSString *dataStr = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
    NSLog(@" •••••••• >>>>>>>> User Info from Push : %@ <<<<<<<< ••••••••",dataStr);
    
    if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
        NSLog(@" >>>>> ACTING ON PUSH NOW <<<<< ");
        [self actOnNotification:userInfo];
    } else if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive ) {
        self.userRespondedToPushWhileClosed = YES;
        NSLog(@" >>>>> WAITING FOR UI TO RENDER BEFORE PLAYING <<<<< ");
    }
    
    completionHandler(UIBackgroundFetchResultNoData);

}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    
    NSLog(@"Did receive local notification");
    self.alarmTask = [application beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    [self fireAlarmClock];
    
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    BOOL success = [AuthenticationManager.sharedInstance.lock handleURL:url sourceApplication:sourceApplication];
#ifdef RELEASE
    if (! success) {
        success = [[FBSDKApplicationDelegate sharedInstance] application:application
                                                                 openURL:url
                                                       sourceApplication:sourceApplication
                                                              annotation:annotation];
    }
#endif
    return success;
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler {
    
    NSLog(@"Handle action with Identifier");
    if ( SEQ(notification.alertAction,@"play-audio") ) {
        [[AudioManager shared] setUserPause:NO]; // Override the user's pause request
        [self.masterViewController handleResponseForNotification];
    }
    completionHandler();
    
}

- (void)actOnNotification:(NSDictionary *)userInfo {
    [[AudioManager shared] setUserPause:NO]; // Override the user's pause request
    [self.masterViewController handleResponseForNotification];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
    if ( [[AudioManager shared] isPlayingAudio] ) {
#ifdef RELEASE
        [Flurry setBackgroundSessionEnabled:YES];
        [[AnalyticsManager shared] setFlurryActiveInBackground:YES];
#endif
        [[SessionManager shared] handleSessionMovingToBackground];
    }
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        if ( ![[UXmanager shared] paused] ) {
            [[UXmanager shared] godPauseOrPlay];
        }
    }
    
    if ( [[QueueManager shared] currentBookmark] ) {
        [[ContentManager shared] saveContext];
    }
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    

    if ( [[SessionManager shared] userIsViewingHeadlines] ) {
        [[AnalyticsManager shared] trackHeadlinesDismissal];
    }
    
    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
        if ( ![[SessionManager shared] sessionLeftDate] ) {
            [[SessionManager shared] setSessionLeftDate:[NSDate date]];
        }
    }
    
    [[ContentManager shared] saveContext];
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // when returning to the foreground, we need to figure out what to display
    // to the user.

#ifdef RELEASE
    if ( [[AnalyticsManager shared] flurryActiveInBackground] ) {
        [Flurry setBackgroundSessionEnabled:NO];
        [[AnalyticsManager shared] setFlurryActiveInBackground:NO];
    }
#endif

    [[SessionManager shared] handleSessionMovingToForeground];
    [[SessionManager shared] expireSessionIfExpired:NO];
    
    [self.masterViewController determinePlayState];

    [[ContentManager shared] sweepBookmarks];

//    if ( [[AudioManager shared] isPlayingAudio] && [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
//        [[SessionManager shared] checkProgramUpdate:YES];
//    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    if ( self.userRespondedToPushWhileClosed ) {
        if ( [self.masterViewController viewHasAppeared] ) {
            [self actOnNotification:nil];
        } else {
            NSLog(@" >>>>>>>>>>> CONTINUE WAITING FOR UI TO CATCH UP <<<<<<<<<<<< ");
        }
    }
    
    [self manuallyCheckAlarm];
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

#ifdef RELEASE
    [FBSDKAppEvents activateApp];
#endif
}

- (void)applicationWillTerminate:(UIApplication *)application {
    

    [[ContentManager shared] saveContext];

    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Training
- (void)onboardForLiveFunctionality {
    [self.onboardingController onboardingSwipingAction:YES];
}


# pragma mark - Stylesheet

- (void)applyStylesheet {
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:255.0f/255.0f
                                                                  green:126.0f/255.0f
                                                                   blue:20.0f/255.0f
                                                                  alpha:1.0f]];
    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlackTranslucent];

    [[UINavigationBar appearance] setTitleTextAttributes:
     @{NSForegroundColorAttributeName: [UIColor whiteColor],
      NSFontAttributeName: [UIFont fontWithName:@"FreightSansProMedium-Regular" size:23.0f]}];
    
    /*[[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil]
    setTitleTextAttributes: @{NSForegroundColorAttributeName:[UIColor whiteColor],
                              NSFontAttributeName:[UIFont fontWithName:@"FreightSansProLight-Regular" size:16.0f]
                              }
     forState:UIControlStateNormal];*/
}


#pragma mark - Alarm Clock

- (void)armAlarmClockWithDate:(NSDate *)date {
    self.alarmDate = date;

    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    NSInteger tisn = fabs([self.alarmDate timeIntervalSinceNow]);
    NSLog(@"Will fire in %ld seconds",(long)tisn);
    self.timer = [NSTimer scheduledTimerWithTimeInterval:tisn
                                                  target:self
                                                selector:@selector(fireAlarmClock)
                                                userInfo:nil
                                                 repeats:NO];

    if ( [[AudioManager shared] isPlayingAudio] ) {
        [[AudioManager shared] adjustAudioWithValue:-0.075
                                         completion:^{
                                             [[AudioManager shared] stopAllAudio];
                                             [self buildTimer];
                                             
                                             self.alarmTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                                                           target:self
                                                                                         selector:@selector(checkAlarmClock)
                                                                                         userInfo:nil
                                                                                          repeats:YES];
    
                                             
                                         }];
        return;
    }
    

    [self buildTimer];
    
    self.alarmTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                  target:self
                                                selector:@selector(checkAlarmClock)
                                                userInfo:nil
                                                 repeats:NO];
    
    
    [[AnalyticsManager shared] logEvent:@"alarmClockArmed"
                         withParameters:nil];
}

- (void)buildTimer {
    UILocalNotification *alarm = [[UILocalNotification alloc] init];

    alarm.alertBody = @"It's time for your fix of KPCC";
    alarm.fireDate = self.alarmDate;
    alarm.soundName = @"alarm_beat.aif";
    alarm.alertAction = @"play-audio";
    alarm.timeZone = [NSTimeZone defaultTimeZone];
    alarm.hasAction = YES;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:alarm];
    
    
    
    NSLog(@"Alarm will fire at : %@",[NSDate stringFromDate:self.alarmDate
                                                 withFormat:@"EEE MM/dd YYYY, hh:mm:ss a"]);
    
    NSArray *local = [[UIApplication sharedApplication] scheduledLocalNotifications];
    NSLog(@"System reports %ld scheduled notes",(long)local.count);
    
    [[UXmanager shared].settings setAlarmFireDate:self.alarmDate];
    [[UXmanager shared] persist];
}

- (void)setAlarmDate:(NSDate *)alarmDate {
    _alarmDate = alarmDate;
    
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    /*NSLog(@"System performing bg fetch at : %@",[NSDate stringFromDate:[NSDate date]
                                                            withFormat:@"hh:mm a"]);
    [self checkAlarmClock];
    
    completionHandler(self.alarmResults);*/
}

- (void)checkAlarmClock {
    
    NSLog(@"Checking... %ld",(long)[[NSDate date] timeIntervalSinceDate:self.alarmDate]);
    if ( self.alarmTimer ) {
        if ( [self.alarmTimer isValid] ) {
            [self.alarmTimer invalidate];
        }
        self.alarmTimer = nil;
    }
    
    if ( [[NSDate date] timeIntervalSinceDate:self.alarmDate] >= 0 ) {

        [self fireAlarmClock];
    } else {
            self.alarmTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                          target:self
                                                        selector:@selector(checkAlarmClock)
                                                        userInfo:nil
                                                              repeats:NO];
    }
    
}

- (void)manuallyCheckAlarm {
    NSArray *local = [[UIApplication sharedApplication] scheduledLocalNotifications];
    NSLog(@"System reports %ld scheduled notes",(long)local.count);
    
    NSDate *alarmDate = [[UXmanager shared].settings alarmFireDate];
    if ( alarmDate ) {
        NSInteger diff = [[NSDate date] timeIntervalSinceDate:alarmDate];
        if ( diff > 0 ) {
            [self endAlarmClock];
        } else {
            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        }
    } else {
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    }
}

- (void)fireAlarmClock {
    
    
    if ( self.alarmTimer ) {
        if ( [self.alarmTimer isValid] ) {
            [self.alarmTimer invalidate];
        }
        self.alarmTimer = nil;
    }
    if ( ![[UXmanager shared].settings alarmFireDate] ) {
        return;
    }
    
    NSLog(@"Alarm Clock is firing");
    
    [self endAlarmClock];
    
    [[AnalyticsManager shared] logEvent:@"alarmClockFired"
                         withParameters:nil];
    
    [[AudioManager shared] setUserPause:NO];
    [self.masterViewController handleResponseForNotification];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"alarm-fired"
                                                        object:nil];
}

- (void)cancelAlarmClock {
    [self endAlarmClock];
    
    [[AnalyticsManager shared] logEvent:@"alarmCanceled"
                         withParameters:nil];
}

- (void)endAlarmClock {
    self.alarmDate = nil;
    [[UXmanager shared].settings setAlarmFireDate:nil];
    [[UXmanager shared] persist];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)killBackgroundTask {
    [[UIApplication sharedApplication] endBackgroundTask:self.alarmTask];
    self.alarmTask = 0;
}

#pragma mark - XFS
- (void)applyXFSButton {
    

    if ( !self.xfsInterface ) {
        self.xfsInterface = [[SCPRXFSViewController alloc]
                             initWithNibName:@"SCPRXFSViewController"
                             bundle:nil];
        self.xfsInterface.view = self.xfsInterface.view;
        CGFloat h = self.masterNavigationController.navigationBar.frame.size.height+20.0f;
        
        [self.window addSubview:self.xfsInterface.view];
        
        NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.xfsInterface.view
                                                                  attribute:NSLayoutAttributeHeight
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:nil
                                                                  attribute:NSLayoutAttributeNotAnAttribute
                                                                 multiplier:1.0
                                                                   constant:h];
        
        NSArray *locks = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[xfs]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:@{ @"xfs" : self.xfsInterface.view }];
        
        NSArray *vLocks = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[xfs]"
                                                                  options:0
                                                                  metrics:nil
                                                                    views:@{ @"xfs" : self.xfsInterface.view }];
        
        self.xfsInterface.view.translatesAutoresizingMaskIntoConstraints = NO;
        
        self.xfsInterface.heightAnchor = height;
        [self.xfsInterface.view addConstraint:height];
        [self.window addConstraints:vLocks];
        [self.window addConstraints:locks];
        [self.window layoutIfNeeded];
        
        [self.xfsInterface applyHeight:h];
 
        self.xfsInterface.view.alpha = 0.0f;
        
    }
    
}

- (void)controlXFSAvailability:(BOOL)available {

    // Override here, kind of kludgy, but...
    if ( !self.xfsInterface.removeOnBalloonDismissal ) {
        if ( ![[SessionManager shared] xFreeStreamIsAvailable] ) {
            available = NO;
        }
    } else {
        if ( !available ) {
            return;
        }
    }
    
    if ( [self.masterViewController homeIsNotRootViewController] ) {
        available = NO;
    }
    if ( [self.masterViewController menuOpen] ) {
        available = NO;
    }
    if ( [self.masterViewController preRollOpen] ) {
        available = NO;
    }
    
    // IPH-17 -- Make sure the scrubbing UI is not up
    if ( [self.masterViewController scrubbing] ) {
        available = NO;
    }

    if ( ![[UXmanager shared] userHasSeenOnboarding]) {
        available = NO;
    }

    self.xfsInterface.view.alpha = available ? 1.0f : 0.0f;
}

- (void)showCoachingBalloonWithText:(NSString *)text {
    [self.xfsInterface showCoachingBalloonWithText:text];
}


#pragma mark - ContentProcessor

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {

}

@end
