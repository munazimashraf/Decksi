#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>

@interface VideoAmbilightEngine : NSObject

+ (instancetype)sharedEngine;

// Multi-Zone Color Arrays (8 Top, 8 Bottom, 6 Left, 6 Right)
@property (nonatomic, strong, readonly) NSArray<NSColor *> *topEdgeColors;
@property (nonatomic, strong, readonly) NSArray<NSColor *> *bottomEdgeColors;
@property (nonatomic, strong, readonly) NSArray<NSColor *> *leftEdgeColors;
@property (nonatomic, strong, readonly) NSArray<NSColor *> *rightEdgeColors;

// Scene metrics
@property (nonatomic, strong, readonly) NSColor *dominantColor;
@property (nonatomic, assign, readonly) CGFloat averageLuminance;
@property (nonatomic, assign, readonly) BOOL hasActiveVideo;

// Adjustments
@property (nonatomic, assign) CGFloat saturationBoost; // 1.0 - 2.0 (default 1.35)
@property (nonatomic, assign) CGFloat smoothingFactor; // 0.1 - 0.5 (default 0.25)

// Process Screen Capture frame
- (void)processVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer;

// Periodic tick for smooth interpolation & demo fallback
- (void)tick;

@end
