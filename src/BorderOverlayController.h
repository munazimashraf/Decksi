#import <Cocoa/Cocoa.h>
#import "BorderGlowView.h"

@interface BorderOverlayController : NSObject

@property (nonatomic, strong, readonly) NSArray<NSWindow *> *overlayWindows;

+ (instancetype)sharedController;

- (void)setupOverlayWindows;
- (void)tearDownOverlayWindows;
- (void)updateVisibility;
- (void)reloadScreens;

@end
