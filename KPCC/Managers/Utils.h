//
//  Utils.h
//  KPCC
//
//  Created by John Meeker on 6/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCPRAppDelegate.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"
#import "NSDate+Helper.h"

//@class SCPRMasterViewController;



#define kUpdateProgramKey @":UPDATE-PROGRAM:"
#define SEQ(a,b) [a isEqualToString:b]

@interface Utils : NSObject

+ (SCPRAppDelegate*)del;

+ (NSDate*)dateFromRFCString:(NSString*)dateString;
+ (NSString*)prettyStringFromRFCDateString:(NSString*)rawDate;
+ (NSString*)prettyStringFromRFCDate:(NSDate*)date;

+ (NSString*)episodeDateStringFromRFCDate:(NSDate *)date;
+ (NSString*)elapsedTimeStringWithPosition:(double)position andDuration:(double)duration;

+ (BOOL)pureNil:(id)object;
+ (BOOL)isRetina;

@end
