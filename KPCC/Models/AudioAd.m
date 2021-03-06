//
//  AudioAd.m
//  KPCC
//
//  Created by John Meeker on 10/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AudioAd.h"

NSUInteger const kAudioAdMaxImpressionUrls = 10;

@implementation AudioAd

+ (NSString *)stringValueForKey:(NSString *)key inDictionary:(NSDictionary *)dictionary
{
    if (dictionary) {
        if ([dictionary[key] isKindOfClass:[NSString class]]) {
            return dictionary[key];
        }
        else if ([dictionary[key] isKindOfClass:[NSDictionary class]]) {
            if ([dictionary[key][@"__text"] isKindOfClass:[NSString class]]) {
                return dictionary[key][@"__text"];
            }
        }
    }
    return nil;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];

    if (self) {

        if ([dictionary[@"InLine"] isKindOfClass:[NSDictionary class]]) {

            NSDictionary *inlineDictionary = dictionary[@"InLine"];

            NSString *impressionUrl = [self.class stringValueForKey:@"Impression" inDictionary:inlineDictionary];

            if (impressionUrl.length) {
                _impressionUrls = @[ impressionUrl ];
            }
            else {
                if ([inlineDictionary[@"Impression"] isKindOfClass:[NSArray class]]) {
                    NSMutableArray *impressionUrls = [NSMutableArray array];
                    for (id impressionUrl in inlineDictionary[@"Impression"]) {
                        if ([impressionUrl isKindOfClass:[NSString class]] && [impressionUrl length]) {
                            [impressionUrls addObject:impressionUrl];
                        }
                    }
                    _impressionUrls = [impressionUrls copy];
                }
            }

            if ([inlineDictionary[@"Creatives"] isKindOfClass:[NSDictionary class]]) {
                if ([inlineDictionary[@"Creatives"][@"Creative"] isKindOfClass:[NSArray class]]) {
                    NSArray *creatives = inlineDictionary[@"Creatives"][@"Creative"];
                    if ([creatives[0] isKindOfClass:[NSDictionary class]]) {
                        if ([creatives[0][@"Linear"] isKindOfClass:[NSDictionary class]]) {
                            [self parseAudioCreative:creatives[0][@"Linear"]];
                            if ([creatives[1] isKindOfClass:[NSDictionary class]]) {
                                if ([creatives[1][@"CompanionAds"] isKindOfClass:[NSDictionary class]]) {
                                    [self parseImageCreative:creatives[1][@"CompanionAds"]];
                                }
                            }
                        }
                    }
                }
            }

        }

    }

    return self;
}

- (NSArray *)impressionUrls
{
    return [_impressionUrls subarrayWithRange:NSMakeRange(0, MIN(_impressionUrls.count, kAudioAdMaxImpressionUrls))];
}

- (void)parseAudioCreative:(NSDictionary *)creative
{
    if ([creative[@"MediaFiles"] isKindOfClass:[NSDictionary class]]) {
        _audioCreativeUrl = [self.class stringValueForKey:@"MediaFile" inDictionary:creative[@"MediaFiles"]];
    }
    else {
        _audioCreativeUrl = nil;
    }

    if (_audioCreativeUrl.length) {
        if ([creative[@"Duration"] isKindOfClass:[NSString class]]) {
            NSArray *components = [creative[@"Duration"] componentsSeparatedByString:@":"];
            if (components.count == 3) {
                double duration = 0.0;
                for (NSString *component in components) {
                    duration = (duration * 60.0) + component.doubleValue;
                }
                _audioCreativeDuration = @(duration);
            }
        }
    }
}

- (void)parseImageCreative:(NSDictionary *)creative
{
    NSDictionary *companionCreative;

    if ([creative[@"Companion"] isKindOfClass:[NSDictionary class]]) {
        companionCreative = creative[@"Companion"];
    }
    else if ([creative[@"Companion"] isKindOfClass:[NSArray class]]) {
        for (id companion in creative[@"Companion"]) {
            if ([companion isKindOfClass:[NSDictionary class]]) {
                if ([companion[@"StaticResource"] isKindOfClass:[NSDictionary class]]) {
                    companionCreative = companion;
                    break;
                }
            }
        }
    }

    if (companionCreative) {
        _imageCreativeUrl = [self.class stringValueForKey:@"StaticResource" inDictionary:companionCreative];
        _clickthroughUrl = [self.class stringValueForKey:@"CompanionClickThrough" inDictionary:companionCreative];
        if ([companionCreative[@"TrackingEvents"] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *trackingEvents = companionCreative[@"TrackingEvents"];
            if ([trackingEvents[@"Tracking"] isKindOfClass:[NSDictionary class]]) {
                NSString *event = [self.class stringValueForKey:@"_event" inDictionary:trackingEvents[@"Tracking"]];
                if ([@"creativeView" isEqualToString:event]) {
                    _creativeTrackingUrl = [self.class stringValueForKey:@"Tracking" inDictionary:trackingEvents];
                }
            }
        }
    }
    
}

@end
