#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

@protocol AudioEngineDelegate <NSObject>
@optional
- (void)audioEngineDidDetectBeatWithIntensity:(CGFloat)intensity;
- (void)audioEngineDidUpdateLevelsBass:(CGFloat)bass mid:(CGFloat)mid high:(CGFloat)high rms:(CGFloat)rms;
@end

@interface AudioEngine : NSObject <SCStreamOutput, SCStreamDelegate>

@property (nonatomic, weak) id<AudioEngineDelegate> delegate;

@property (nonatomic, readonly) CGFloat currentBeatLevel;  // 0.0 - 1.0 (peaks on beat, decays)
@property (nonatomic, readonly) CGFloat currentBassLevel;  // 0.0 - 1.0
@property (nonatomic, readonly) CGFloat currentMidLevel;   // 0.0 - 1.0
@property (nonatomic, readonly) CGFloat currentHighLevel;  // 0.0 - 1.0
@property (nonatomic, readonly) CGFloat currentRMS;        // 0.0 - 1.0
@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) BOOL isInternalSystemAudio;

+ (instancetype)sharedEngine;

- (BOOL)start;
- (void)stop;
- (void)switchMode:(NSInteger)mode; // 0 = Internal System Audio, 1 = Demo, 2 = Microphone

@end
