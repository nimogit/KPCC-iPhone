//
//  AudioManager.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>


#ifdef SHORTENED_BUFFER
static long kStreamBufferLimit = 1*60;
static long kStreamCorrectionTolerance = 60*5;
#else
static long kStreamBufferLimit = 4*60*60;
static long kStreamCorrectionTolerance = 60*5;
#endif

#define kLargeSkipInterval 60*10
#define kSmallSkipInterval 20.0

#define kHLS [[AudioManager shared] standardHlsStream]
/*
#ifdef USE_TEST_STREAM
#define kHLSLiveStreamURL @"http://hls.kqed.org/hls/smil:itunes.smil/playlist.m3u8"
#else
#ifdef BETA
//#define kHLSLiveStreamURLBase @"http://streammachine-test.scprdev.org:8020/sg/test.m3u8"
#define kHLSLiveStreamURLBase @"http://streammachine-hls001.scprdev.org/sg/kpcc-aac.m3u8"
#define kHLSLiveStreamURL [NSString stringWithFormat:@"%@?ua=KPCCiPhone-%@",kHLSLiveStreamURLBase,[Utils urlSafeVersion]]
#else
#ifdef FORCE_TEST_STREAM
#define kHLSLiveStreamURLBase @"http://streammachine-test.scprdev.org:8020/sg/test.m3u8"
#define kHLSLiveStreamURL [NSString stringWithFormat:@"%@?ua=KPCCiPhone-%@",kHLSLiveStreamURLBase,[Utils urlSafeVersion]]
#else
#define kHLSLiveStreamURL [NSString stringWithFormat:@"%@?ua=KPCCiPhone-%@",@"http://streammachine-hls001.scprdev.org/sg/kpcc-aac.m3u8",[Utils urlSafeVersion]]
#endif
#endif
#endif

#define kLiveStreamURL @"http://live.scpr.org/kpcclive"
#define kLiveStreamNoPreRollURL @"http://live.scpr.org/kpcclive?preskip=true"
#define kLiveStreamAACURL @"http://live.scpr.org/aac"
#define kLiveStreamAACNoPreRollURL @"http://live.scpr.org/aac?preskip=true"*/

#define kLiveStreamPreRollThreshold 3600

#define kFailedConnectionAudioFile @"Wood_Crash"
#define kFailedStreamAudioFile @"Glass_Crash"

#ifdef DEBUG
#	define SCPRDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#	define SCPRDebugLog(...)
#endif

@class AudioChunk;

typedef NS_ENUM(NSUInteger, AudioMode) {
    AudioModeNeutral = 0,
    AudioModeLive,
    AudioModeOnDemand,
    AudioModeOnboarding,
    AudioModePreroll
};

typedef NS_ENUM(NSUInteger, StreamState) {
    StreamStateHealthy = 0,
    StreamStateLostConnectivity = 1,
    StreamStateServerFail = 2,
    StreamStateUnknown = 3
};

typedef NS_ENUM(NSUInteger, StreamStatus) {
    StreamStatusStopped = 0,
    StreamStatusPlaying = 1,
    StreamStatusPaused = 2
};

@protocol AudioManagerDelegate <NSObject>
@optional
- (void)handleUIForFailedConnection;
- (void)handleUIForFailedStream;
- (void)handleUIForRecoveredStream;
- (void)onTimeChange;
- (void)onRateChange;
- (void)onSeekCompleted;
- (void)interfere;
- (void)onDemandAudioFailed;
- (void)onDemandSeekCompleted;
- (void)restoreUIIfNeeded;

@end

#define kPreferredPeakBitRateTolerance 1000
#define kImpatientWaitingTolerance 15.0
#define kGiveUpTolerance 30.0
#define kBookmarkingTolerance 10

@interface AudioManager : NSObject<AVAssetResourceLoaderDelegate>

+ (AudioManager*)shared;

@property (readwrite, unsafe_unretained) id<AudioManagerDelegate> delegate;

@property (nonatomic,strong) id timeObserver;

@property AVPlayer *audioPlayer;
@property AVPlayerItem *playerItem;
@property AVAudioPlayer *localAudioPlayer;

@property StreamStatus status;
@property long lastPreRoll;

@property NSDate *currentDate;
@property NSDate *minSeekableDate;
@property NSDate *maxSeekableDate;
@property NSDate *requestedSeekDate;
@property NSDate *relativeFauxDate;

@property long latencyCorrection;


@property (strong,nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic,strong) NSOperationQueue *fadeQueue;


@property long bufferObservationCount;

@property CGFloat savedVolume;
@property CGFloat savedVolumeFromMute;
@property Float64 onDemandSeekPosition;

@property BOOL seekRequested;
@property BOOL bufferMutex;
@property BOOL waitForFirstTick;
@property BOOL autoMuted;
@property BOOL temporaryMutex;
@property BOOL easeInAudio;
@property BOOL waitForSeek;
@property BOOL waitForOnDemandSeek;
@property BOOL prerollPlaying;
@property BOOL tryAgain;
@property BOOL dumpedOnce;
@property BOOL recoveryGateOpen;
@property BOOL loggingGateOpen;
@property BOOL reactivate;
@property BOOL dropoutOccurred;
@property BOOL seekWillEffectBuffer;
@property BOOL streamStabilized;
@property BOOL smooth;
@property BOOL userPause;
@property BOOL waitingForRecovery;
@property BOOL beginNormally;
@property BOOL bufferEmpty;
@property BOOL streamWarning;
@property BOOL appGaveUp;
@property BOOL audioOutputSourceChanging;

@property (nonatomic, strong) NSMutableDictionary *localBufferSample;

@property UIBackgroundTaskIdentifier rescueTask;

@property NSInteger failoverCount;

@property (nonatomic, copy) NSString *previousUrl;
@property (nonatomic, strong) NSDate *queuedSeekDate;

@property NSInteger onboardingSegment;
@property (nonatomic) AudioMode currentAudioMode;

- (NSString*)standardHlsStream;
- (NSString*)streamingURL:(BOOL)hls preskip:(BOOL)preskip mp3:(BOOL)mp3;

- (void)playQueueItemWithUrl:(NSString *)url;
- (void)playQueueItem:(AudioChunk*)chunk;
- (void)playLiveStream;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *liveStreamURL;
- (void)startStream;
- (void)playAudio;
- (void)pauseAudio;
- (void)stopAllAudio;
- (void)muteAudio;
- (void)unmuteAudio;
- (void)buildStreamer:(NSString*)urlString;
- (void)buildStreamer:(NSString*)urlString local:(BOOL)local;
- (void)printStatus;
- (void)playOnboardingAudio:(NSInteger)segment;
- (void)sanitizeFromOnboarding;

// Recovery
- (void)waitPatiently;
- (void)attemptToRecover;
- (void)interruptAutorecovery;
- (void)stopWaiting;
- (void)localSample:(CMTime)time;

@property (NS_NONATOMIC_IOSONLY, getter=isStreamPlaying, readonly) BOOL streamPlaying;
@property (NS_NONATOMIC_IOSONLY, getter=isStreamBuffering, readonly) BOOL streamBuffering;

@property (NS_NONATOMIC_IOSONLY, readonly) double indicatedBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMaxBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMinBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *currentDateTimeString;

@property NSInteger frameCount;

@property BOOL audioCheating;
@property BOOL ignoreDriftTolerance;
@property BOOL calibrating;

@property NSTimeInterval newPositionDelta;

@property (nonatomic, strong) NSTimer *kickstartTimer;
@property (nonatomic, strong) NSTimer *giveupTimer;
@property (nonatomic, copy) NSDate *seekTargetReferenceDate;

- (void)updateNowPlayingInfoWithAudio:(id)audio;

- (void)seekToPercent:(CGFloat)percent;
- (void)seekToDate:(NSDate *)date;
- (void)seekToDate:(NSDate *)date forward:(BOOL)forward failover:(BOOL)failover;
- (void)specialSeekToDate:(NSDate*)date;
- (void)recalibrateAfterScrub;

- (void)forwardSeekLiveWithCompletion:(CompletionBlock)completion;
- (void)forwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion;
- (void)backwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion;
- (void)intervalSeekWithTimeInterval:(NSTimeInterval)interval completion:(CompletionBlock)completion;
- (void)finishIntervalSeek:(NSTimeInterval)interval completion:(CompletionBlock)completion;
- (void)finishSeekToLive;

- (void)backwardSeekToBeginningOfProgram;

- (void)forwardSeekFifteenSecondsWithCompletion:(CompletionBlock)completion;
- (void)backwardSeekFifteenSecondsWithCompletion:(CompletionBlock)completion;

- (void)analyzeStreamError:(NSString*)comments;
- (void)adjustAudioWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)threadedAdjustWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)takedownAudioPlayer;
- (void)resetPlayer;

- (BOOL)isPlayingAudio;
- (BOOL)verifyPositionAuthenticity;
- (void)invalidateTimeObserver;
- (void)startObservingTime;

- (NSString*)avPlayerSessionString;

- (NSDate*)cookDateForActualSchedule:(NSDate*)date;

#ifdef DEBUG
@property long frame;
@property (nonatomic,strong) NSDate *previousCD;
- (void)dump:(BOOL)superVerbose;
- (void)streamFrame;
@property (nonatomic, strong) NSTimer *multipurposeTimer;

#endif

@end
