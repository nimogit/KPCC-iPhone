//
//  UIColor+UICustom.h
//
//  Created by Ben Hochberg on 7/25/14.
//

#import <UIKit/UIKit.h>

@interface UIColor (UICustom)

- (UIColor*)translucify:(CGFloat)alpha;
+ (UIColor*)colorWithHex:(UInt32)hex;
+ (UIColor*)kpccOrangeColor;
+ (UIColor*)virtualBlackColor;
+ (UIColor*)cloudColor;
+ (UIColor*)angryCloudColor;
+ (UIColor*)kpccPeriwinkleColor;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) UIColor *intensify;
+ (UIColor*)virtualWhiteColor;
+ (UIColor*)paleHorseColor;
+ (UIColor*)kpccSlateColor;
+ (UIColor*)kpccAsphaltColor;
+ (UIColor*)kpccSoftOrangeColor;
+ (UIColor*)kpccSubtleGrayColor;
+ (UIColor*)kpccBalloonBlueColor;
+ (UIColor*)number2pencilColor;
+ (UIColor*)kpccDividerGrayColor;

@end
