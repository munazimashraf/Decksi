#import "BorderOverlayController.h"
#import "BorderGlowView.h"
#import "Settings.h"

@interface DecksiOverlayWindow : NSWindow
@end

@implementation DecksiOverlayWindow
- (BOOL)canBecomeKeyWindow {
    return [Settings sharedSettings].blackoutMode;
}
- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 53) { // ESC key
        if ([Settings sharedSettings].blackoutMode) {
            [Settings sharedSettings].blackoutMode = NO;
            [[Settings sharedSettings] saveSettings];
            [[BorderOverlayController sharedController] updateVisibility];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"DecksiBlackoutModeDidChange" object:nil];
            return;
        }
    } else if (event.keyCode == 48) { // TAB key cycles through Lyrics Styles!
        if ([Settings sharedSettings].blackoutMode) {
            Settings *s = [Settings sharedSettings];
            s.lyricsStyle = (s.lyricsStyle + 1) % 4;
            [s saveSettings];
            [[BorderOverlayController sharedController] updateVisibility];
            return;
        }
    }
    [super keyDown:event];
}
@end

@interface BorderOverlayController ()
@property (nonatomic, strong) NSMutableArray<DecksiOverlayWindow *> *windows;
@property (nonatomic, strong) NSMutableArray<BorderGlowView *> *views;
@property (nonatomic, strong) NSTimer *animationTimer;
@end

@implementation BorderOverlayController

+ (instancetype)sharedController {
    static BorderOverlayController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BorderOverlayController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _windows = [NSMutableArray array];
        _views = [NSMutableArray array];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(screenParametersChanged:)
                                                     name:NSApplicationDidChangeScreenParametersNotification
                                                   object:nil];
                                                   
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateVisibility)
                                                     name:@"DecksiBlackoutModeDidChange"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self tearDownOverlayWindows];
}

- (NSArray<NSWindow *> *)overlayWindows {
    return [self.windows copy];
}

- (void)setupOverlayWindows {
    [self tearDownOverlayWindows];
    
    NSArray<NSScreen *> *screens = [NSScreen screens];
    NSLog(@"Setting up Decksi overlay for %lu screens...", (unsigned long)screens.count);
    
    for (NSScreen *screen in screens) {
        NSRect frame = screen.frame;
        
        DecksiOverlayWindow *win = [[DecksiOverlayWindow alloc] initWithContentRect:frame
                                                                          styleMask:NSWindowStyleMaskBorderless
                                                                            backing:NSBackingStoreBuffered
                                                                              defer:NO];
        win.opaque = NO;
        win.backgroundColor = [NSColor clearColor];
        win.hasShadow = NO;
        win.level = NSFloatingWindowLevel;
        win.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                  NSWindowCollectionBehaviorStationary |
                                  NSWindowCollectionBehaviorIgnoresCycle |
                                  NSWindowCollectionBehaviorFullScreenAuxiliary;
        
        BorderGlowView *view = [[BorderGlowView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
        win.contentView = view;
        [view updateFrameRateTick];
        
        [win orderFrontRegardless];
        [self.windows addObject:win];
        [self.views addObject:view];
    }
    
    [self startAnimationLoop];
    [self updateVisibility];
}

- (void)tearDownOverlayWindows {
    [self stopAnimationLoop];
    for (NSWindow *win in self.windows) {
        [win orderOut:nil];
    }
    [self.windows removeAllObjects];
    [self.views removeAllObjects];
}

- (void)startAnimationLoop {
    if (self.animationTimer) return;
    
    __weak typeof(self) weakSelf = self;
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf animationTick];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.animationTimer forMode:NSRunLoopCommonModes];
}

- (void)stopAnimationLoop {
    [self.animationTimer invalidate];
    self.animationTimer = nil;
}

- (void)animationTick {
    if (![Settings sharedSettings].enabled) return;
    for (BorderGlowView *view in self.views) {
        [view updateFrameRateTick];
    }
}

- (void)updateVisibility {
    Settings *s = [Settings sharedSettings];
    BOOL enabled = s.enabled;
    BOOL blackout = s.blackoutMode;
    
    for (DecksiOverlayWindow *win in self.windows) {
        win.alphaValue = enabled ? 1.0 : 0.0;
        
        if (blackout && enabled) {
            // When in blackout mode, capture mouse clicks & keys so pressing Esc or clicking exits
            win.ignoresMouseEvents = NO;
            [win makeKeyAndOrderFront:nil];
            [NSApp activateIgnoringOtherApps:YES];
        } else {
            // In normal mode, complete click-through!
            win.ignoresMouseEvents = YES;
            if (enabled) {
                [win orderFrontRegardless];
            }
        }
    }
    
    for (BorderGlowView *view in self.views) {
        [view setNeedsDisplay:YES];
    }
}

- (void)reloadScreens {
    [self setupOverlayWindows];
}

- (void)screenParametersChanged:(NSNotification *)notif {
    [self reloadScreens];
}

@end
