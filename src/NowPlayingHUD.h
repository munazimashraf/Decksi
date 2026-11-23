#import <Cocoa/Cocoa.h>

@interface NowPlayingHUD : NSObject

+ (instancetype)sharedHUD;

- (void)showWithTrack:(NSString *)track artist:(NSString *)artist album:(NSString *)album colors:(NSArray<NSColor *> *)colors;
- (void)hideHUD;
- (void)updateEqualizerBarsWithBass:(CGFloat)bass mid:(CGFloat)mid high:(CGFloat)high beat:(CGFloat)beat;

@end
