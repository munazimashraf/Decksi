#import "NowPlayingHUD.h"
#import "Settings.h"

@interface NowPlayingHUDView : NSView
@property (nonatomic, strong) NSString *track;
@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSArray<NSColor *> *palette;
@property (nonatomic, assign) CGFloat bar1;
@property (nonatomic, assign) CGFloat bar2;
@property (nonatomic, assign) CGFloat bar3;
@property (nonatomic, assign) CGFloat bar4;
@end

@implementation NowPlayingHUDView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    NSRect bounds = self.bounds;
    
    // Draw Frosted Dark Capsule Background
    NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:18.0 yRadius:18.0];
    [[NSColor colorWithCalibratedRed:0.08 green:0.09 blue:0.14 alpha:0.92] setFill];
    [pill fill];
    
    // Glowing gradient border
    NSColor *c1 = (self.palette.count > 0) ? self.palette[0] : [NSColor systemCyanColor];
    NSColor *c2 = (self.palette.count > 1) ? self.palette[1] : [NSColor systemPinkColor];
    
    CGColorRef cg1 = [c1 CGColor];
    CGColorRef cg2 = [c2 CGColor];
    CFArrayRef colors = (__bridge CFArrayRef)@[(__bridge id)cg1, (__bridge id)cg2];
    CGGradientRef grad = CGGradientCreateWithColors(NULL, colors, NULL);
    
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, pill.CGPath);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextReplacePathWithStrokedPath(ctx);
    CGContextClip(ctx);
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, bounds.size.height), CGPointMake(bounds.size.width, 0), 0);
    CGContextRestoreGState(ctx);
    CGGradientRelease(grad);
    
    // Draw Vinyl / Music Icon on left
    CGFloat iconX = 14.0;
    CGFloat iconY = (bounds.size.height - 20.0) / 2.0;
    NSRect iconRect = NSMakeRect(iconX, iconY, 20.0, 20.0);
    NSBezierPath *disk = [NSBezierPath bezierPathWithOvalInRect:iconRect];
    [c1 setFill];
    [disk fill];
    
    NSBezierPath *innerDisk = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(iconX + 6.0, iconY + 6.0, 8.0, 8.0)];
    [[NSColor colorWithCalibratedRed:0.08 green:0.09 blue:0.14 alpha:1.0] setFill];
    [innerDisk fill];
    
    // Draw Track Title & Artist Text
    CGFloat textX = 42.0;
    CGFloat textWidth = bounds.size.width - textX - 44.0;
    
    NSDictionary *titleAttr = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:12.0],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSDictionary *artistAttr = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10.5],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.75 alpha:1.0]
    };
    
    NSString *displayTitle = self.track.length > 0 ? self.track : @"Prixm Edge";
    NSString *displayArtist = self.artist.length > 0 ? self.artist : @"Music Reactive";
    
    [displayTitle drawInRect:NSMakeRect(textX, bounds.size.height - 18.0, textWidth, 16.0) withAttributes:titleAttr];
    [displayArtist drawInRect:NSMakeRect(textX, 4.0, textWidth, 14.0) withAttributes:artistAttr];
    
    // Draw 4 Animated Audio Equalizer Bars on right
    CGFloat eqX = bounds.size.width - 32.0;
    CGFloat barW = 3.0;
    CGFloat barGap = 2.5;
    CGFloat maxH = 14.0;
    CGFloat baseY = (bounds.size.height - maxH) / 2.0;
    
    CGFloat heights[4] = {
        fmax(3.0, self.bar1 * maxH),
        fmax(4.0, self.bar2 * maxH),
        fmax(3.0, self.bar3 * maxH),
        fmax(2.0, self.bar4 * maxH)
    };
    
    [c2 setFill];
    for (int i = 0; i < 4; i++) {
        NSRect barRect = NSMakeRect(eqX + i * (barW + barGap), baseY + (maxH - heights[i]) / 2.0, barW, heights[i]);
        NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect:barRect xRadius:1.5 yRadius:1.5];
        [bp fill];
    }
}

@end

@interface NowPlayingHUD ()
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NowPlayingHUDView *hudView;
@property (nonatomic, strong) NSTimer *autoHideTimer;
@end

@implementation NowPlayingHUD

+ (instancetype)sharedHUD {
    static NowPlayingHUD *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NowPlayingHUD alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupWindow];
    }
    return self;
}

- (void)setupWindow {
    CGFloat w = 320.0;
    CGFloat h = 42.0;
    NSScreen *screen = [NSScreen mainScreen];
    CGFloat screenW = screen ? screen.frame.size.width : 1440.0;
    CGFloat screenH = screen ? screen.frame.size.height : 900.0;
    
    // Position near the top center (below macOS menu bar / notch)
    NSRect frame = NSMakeRect((screenW - w) / 2.0, screenH - h - 40.0, w, h);
    
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskBorderless
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.opaque = NO;
    self.window.backgroundColor = [NSColor clearColor];
    self.window.hasShadow = YES;
    self.window.ignoresMouseEvents = YES;
    self.window.level = NSScreenSaverWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorStationary |
                                     NSWindowCollectionBehaviorIgnoresCycle;
    
    self.hudView = [[NowPlayingHUDView alloc] initWithFrame:NSMakeRect(0, 0, w, h)];
    self.window.contentView = self.hudView;
    self.window.alphaValue = 0.0;
}

- (void)showWithTrack:(NSString *)track artist:(NSString *)artist album:(NSString *)album colors:(NSArray<NSColor *> *)colors {
    if (![Settings sharedSettings].enabled) return;
    
    self.hudView.track = track;
    self.hudView.artist = artist;
    self.hudView.palette = colors;
    [self.hudView setNeedsDisplay:YES];
    
    [self.autoHideTimer invalidate];
    [self.window orderFrontRegardless];
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.35;
        self.window.animator.alphaValue = 1.0;
    }];
    
    __weak typeof(self) weakSelf = self;
    self.autoHideTimer = [NSTimer scheduledTimerWithTimeInterval:4.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [weakSelf hideHUD];
    }];
}

- (void)hideHUD {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.duration = 0.45;
        self.window.animator.alphaValue = 0.0;
    } completionHandler:^{
        [self.window orderOut:nil];
    }];
}

- (void)updateEqualizerBarsWithBass:(CGFloat)bass mid:(CGFloat)mid high:(CGFloat)high beat:(CGFloat)beat {
    if (self.window.alphaValue <= 0.05) return;
    
    self.hudView.bar1 = fmin(1.0, bass * 1.2 + beat * 0.4);
    self.hudView.bar2 = fmin(1.0, mid * 1.4);
    self.hudView.bar3 = fmin(1.0, high * 1.5);
    self.hudView.bar4 = fmin(1.0, beat * 0.9 + mid * 0.5);
    
    [self.hudView setNeedsDisplay:YES];
}

@end
