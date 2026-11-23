#import <Cocoa/Cocoa.h>

@interface MenuBarController : NSObject

+ (instancetype)sharedController;

- (void)setupMenuBarItem;
- (void)showPreferencesWindow;

@end
