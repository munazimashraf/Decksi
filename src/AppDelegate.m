#import "AppDelegate.h"
#import "Settings.h"
#import "BorderOverlayController.h"
#import "AudioEngine.h"
#import "MusicDetector.h"
#import "MenuBarController.h"
#import "NowPlayingHUD.h"
#import "LyricsManager.h"

@interface AppDelegate () <MusicDetectorDelegate, AudioEngineDelegate>
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"Initializing Decksi for Mac (Music-Reactive RGB Lighting & Lyrics Blackout)...");
    
    // Accessory app: lives purely in macOS Menu Bar
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    // 1. Load Settings
    [[Settings sharedSettings] loadSettings];
    
    // 2. Setup Screen Border Overlays
    [[BorderOverlayController sharedController] setupOverlayWindows];
    
    // 3. Setup Menu Bar Icon & Menus
    [[MenuBarController sharedController] setupMenuBarItem];
    
    // 4. Start Music App Tracking (Apple Music & Spotify)
    [MusicDetector sharedDetector].delegate = self;
    [[MusicDetector sharedDetector] startMonitoring];
    
    // 5. Start Audio Analysis Engine
    [AudioEngine sharedEngine].delegate = self;
    [[AudioEngine sharedEngine] start];
    
    NSLog(@"Decksi successfully started! RGB Screen Border is now live.");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    NSLog(@"Terminating Decksi...");
    [[AudioEngine sharedEngine] stop];
    [[MusicDetector sharedDetector] stopMonitoring];
    [[BorderOverlayController sharedController] tearDownOverlayWindows];
}

#pragma mark - MusicDetectorDelegate

- (void)musicDetectorTrackDidChange:(NSString *)track artist:(NSString *)artist album:(NSString *)album colors:(NSArray<NSColor *> *)colors {
    NSLog(@"Decksi track changed: %@ by %@", track, artist);
    
    // Fetch lyrics for blackout mode
    [[LyricsManager sharedManager] fetchLyricsForTrack:track artist:artist];
    
    // Show Dynamic Island HUD Pill
    if ([Settings sharedSettings].nowPlayingHUDEnabled && ![Settings sharedSettings].blackoutMode) {
        [[NowPlayingHUD sharedHUD] showWithTrack:track artist:artist album:album colors:colors];
    }
}

- (void)musicDetectorPlaybackStateDidChange:(BOOL)isPlaying {
    NSLog(@"Decksi playback state changed: %@", isPlaying ? @"PLAYING" : @"PAUSED");
    [[LyricsManager sharedManager] updatePlaybackPosition:[LyricsManager sharedManager].playbackPosition isPlaying:isPlaying];
}

#pragma mark - AudioEngineDelegate

- (void)audioEngineDidDetectBeatWithIntensity:(CGFloat)intensity {
    // Handled in frame update
}

- (void)audioEngineDidUpdateLevelsBass:(CGFloat)bass mid:(CGFloat)mid high:(CGFloat)high rms:(CGFloat)rms {
    if ([Settings sharedSettings].nowPlayingHUDEnabled && ![Settings sharedSettings].blackoutMode) {
        [[NowPlayingHUD sharedHUD] updateEqualizerBarsWithBass:bass
                                                          mid:mid
                                                         high:high
                                                         beat:[AudioEngine sharedEngine].currentBeatLevel];
    }
}

@end
