#import "MenuBarController.h"
#import "Settings.h"
#import "BorderOverlayController.h"
#import "AudioEngine.h"
#import "MusicDetector.h"
#import "NowPlayingHUD.h"
#import "ParticleEngine.h"
#import "LyricsManager.h"
#import <CoreGraphics/CoreGraphics.h>

@interface MenuBarController () <NSWindowDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong) NSMenuItem *headerItem;
@property (nonatomic, strong) NSMenuItem *trackInfoItem;
@property (nonatomic, strong) NSMenuItem *toggleItem;
@property (nonatomic, strong) NSMenuItem *blackoutItem;

// Preferences HUD Window
@property (nonatomic, strong) NSWindow *prefsWindow;
@property (nonatomic, strong) NSSlider *borderWidthSlider;
@property (nonatomic, strong) NSSlider *glowRadiusSlider;
@property (nonatomic, strong) NSSlider *sensitivitySlider;
@property (nonatomic, strong) NSSlider *reactivitySlider;

@property (nonatomic, strong) NSTextField *borderWidthLabel;
@property (nonatomic, strong) NSTextField *glowRadiusLabel;
@property (nonatomic, strong) NSTextField *sensitivityLabel;
@property (nonatomic, strong) NSTextField *reactivityLabel;

@property (nonatomic, strong) NSButton *blackoutCheck;
@property (nonatomic, strong) NSButton *lyricsCheck;
@property (nonatomic, strong) NSButton *particlesCheck;
@property (nonatomic, strong) NSButton *wavesCheck;
@property (nonatomic, strong) NSButton *shockwavesCheck;
@property (nonatomic, strong) NSButton *hudCheck;
@property (nonatomic, strong) NSPopUpButton *borderDesignPopUp;
@property (nonatomic, strong) NSPopUpButton *lyricsStylePopUp;

@property (nonatomic, strong) NSProgressIndicator *bassMeter;
@property (nonatomic, strong) NSProgressIndicator *midMeter;
@property (nonatomic, strong) NSProgressIndicator *highMeter;
@property (nonatomic, strong) NSProgressIndicator *beatMeter;
@property (nonatomic, strong) NSTimer *meterTimer;

@end

@implementation MenuBarController

+ (instancetype)sharedController {
    static MenuBarController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MenuBarController alloc] init];
    });
    return instance;
}

- (void)setupMenuBarItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [self createDecksiStatusIcon];
    self.statusItem.button.toolTip = @"Decksi — Audio-Reactive RGB Lighting & Lyrics";
    
    [self rebuildMenu];
    
    __weak typeof(self) weakSelf = self;
    [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf updateMenuHeader];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rebuildMenu)
                                                 name:@"DecksiBlackoutModeDidChange"
                                               object:nil];
}

- (NSImage *)createDecksiStatusIcon {
    NSSize size = NSMakeSize(18, 18);
    NSImage *img = [[NSImage alloc] initWithSize:size];
    [img lockFocus];
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(9, 16)];
    [path lineToPoint:NSMakePoint(16, 4)];
    [path lineToPoint:NSMakePoint(2, 4)];
    [path closePath];
    
    [path setLineWidth:1.6];
    [[NSColor labelColor] setStroke];
    [path stroke];
    
    NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(7.5, 6.5, 3, 3)];
    [[NSColor systemCyanColor] setFill];
    [dot fill];
    
    [img unlockFocus];
    [img setTemplate:YES];
    return img;
}

- (void)rebuildMenu {
    Settings *s = [Settings sharedSettings];
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Decksi"];
    
    // 1. App Title Header
    self.headerItem = [[NSMenuItem alloc] initWithTitle:@"Decksi — Edge RGB & Lyrics" action:nil keyEquivalent:@""];
    [self.headerItem setEnabled:NO];
    [menu addItem:self.headerItem];
    
    // 2. Now Playing / Status
    NSString *trackText = s.isMusicPlaying ? [NSString stringWithFormat:@"🎵 Playing: %@", s.currentTrackInfo] : @"🎵 Idle (Awaiting Music)";
    self.trackInfoItem = [[NSMenuItem alloc] initWithTitle:trackText action:nil keyEquivalent:@""];
    [self.trackInfoItem setEnabled:NO];
    [menu addItem:self.trackInfoItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 3. Blackout Mode Toggle (Cmd + Shift + B)
    NSString *blackoutTitle = s.blackoutMode ? @"Exit Blackout Screen Mode" : @"🌙 Turn ON Blackout Screen Mode (RGB + Lyrics)";
    self.blackoutItem = [[NSMenuItem alloc] initWithTitle:blackoutTitle action:@selector(toggleBlackout:) keyEquivalent:@"b"];
    [self.blackoutItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    [self.blackoutItem setTarget:self];
    [menu addItem:self.blackoutItem];
    
    // 4. Enable / Disable Toggle (Cmd + Shift + P)
    NSString *toggleTitle = s.enabled ? @"Turn Lighting OFF" : @"Turn Lighting ON";
    self.toggleItem = [[NSMenuItem alloc] initWithTitle:toggleTitle action:@selector(toggleEnabled:) keyEquivalent:@"p"];
    [self.toggleItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    [self.toggleItem setTarget:self];
    [menu addItem:self.toggleItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 5. Lyrics Display Styles Submenu
    NSMenuItem *lyricsItem = [[NSMenuItem alloc] initWithTitle:@"Lyrics Display Style" action:nil keyEquivalent:@""];
    NSMenu *lyricsMenu = [[NSMenu alloc] initWithTitle:@"Lyrics Styles"];
    NSArray *lyricsStyles = @[
        @"🏛️ Classical 3D Amphitheater (Angled Horizon & Marble Reflection)",
        @"🎭 Grand Opera House Stage (Theatrical Spotlights & Roman Serifs)",
        @"💿 Oblique 3D Turntable Lounge (Tilted Vinyl & Gilded Plaque)",
        @"🎼 Tilted 3D Chamber Manuscript (Acoustic Strings & Gold Trim)"
    ];
    for (NSInteger i = 0; i < lyricsStyles.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:lyricsStyles[i] action:@selector(selectLyricsStyle:) keyEquivalent:@""];
        item.tag = i;
        item.target = self;
        item.state = (s.lyricsStyle == i) ? NSControlStateValueOn : NSControlStateValueOff;
        [lyricsMenu addItem:item];
    }
    lyricsItem.submenu = lyricsMenu;
    [menu addItem:lyricsItem];
    
    // 6. Border Designs Submenu
    NSMenuItem *designItem = [[NSMenuItem alloc] initWithTitle:@"Border Design Style" action:nil keyEquivalent:@""];
    NSMenu *designMenu = [[NSMenu alloc] initWithTitle:@"Border Designs"];
    NSArray *designNames = @[
        @"✨ Classic Ambient Glow",
        @"📊 Equalizer Spectrum Bars",
        @"💡 WS2812B Dotted LED Strip",
        @"⚡ Cyber Circuit Tracks",
        @"💫 Double Neon Laser Rings",
        @"🌊 Liquid Wave Ribbon"
    ];
    for (NSInteger i = 0; i < designNames.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:designNames[i] action:@selector(selectBorderDesign:) keyEquivalent:@""];
        item.tag = i;
        item.target = self;
        item.state = (s.borderDesign == i) ? NSControlStateValueOn : NSControlStateValueOff;
        [designMenu addItem:item];
    }
    designItem.submenu = designMenu;
    [menu addItem:designItem];
    
    // 7. Color Presets Submenu
    NSMenuItem *presetsItem = [[NSMenuItem alloc] initWithTitle:@"Color Presets" action:nil keyEquivalent:@""];
    NSMenu *presetsMenu = [[NSMenu alloc] initWithTitle:@"Color Presets"];
    NSArray *presetNames = @[
        @"🌈 Prism RGB Rainbow Spectrum",
        @"⚡ Cyberpunk 2077 (Cyan & Pink)",
        @"🔥 Sunset Ember (Crimson & Gold)",
        @"🌌 Cosmic Aurora (Emerald & Violet)",
        @"☀️ Solar Plasma / Firestorm (Gold & Magma)",
        @"🧪 Toxic Matrix (Acid Lime & Emerald)",
        @"🌴 Synthwave Sunset (80s Purple & Peach)",
        @"🎵 Dynamic Music Sync (Spotify/Apple Music)",
        @"⚪ Pure Hyper-White (Clean Halo)"
    ];
    for (NSInteger i = 0; i < presetNames.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:presetNames[i] action:@selector(selectPreset:) keyEquivalent:@""];
        item.tag = i;
        item.target = self;
        item.state = (s.preset == i) ? NSControlStateValueOn : NSControlStateValueOff;
        [presetsMenu addItem:item];
    }
    presetsItem.submenu = presetsMenu;
    [menu addItem:presetsItem];
    
    // 8. Visual FX Submenu
    NSMenuItem *fxItem = [[NSMenuItem alloc] initWithTitle:@"Visual FX Modifiers" action:nil keyEquivalent:@""];
    NSMenu *fxMenu = [[NSMenu alloc] initWithTitle:@"Visual FX"];
    
    NSMenuItem *itemWaves = [[NSMenuItem alloc] initWithTitle:@"🌊 Equalizer Wave Ripples" action:@selector(toggleWaves:) keyEquivalent:@""];
    itemWaves.target = self;
    itemWaves.state = s.waveRipplesEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [fxMenu addItem:itemWaves];
    
    NSMenuItem *itemParticles = [[NSMenuItem alloc] initWithTitle:@"✨ Cosmic Particle Sparkles" action:@selector(toggleParticles:) keyEquivalent:@""];
    itemParticles.target = self;
    itemParticles.state = s.particlesEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [fxMenu addItem:itemParticles];
    
    NSMenuItem *itemShock = [[NSMenuItem alloc] initWithTitle:@"💥 Corner Bass Shockwaves" action:@selector(toggleShockwaves:) keyEquivalent:@""];
    itemShock.target = self;
    itemShock.state = s.shockwavesEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [fxMenu addItem:itemShock];
    
    NSMenuItem *itemHUD = [[NSMenuItem alloc] initWithTitle:@"💊 Floating Now Playing HUD Pill" action:@selector(toggleHUD:) keyEquivalent:@""];
    itemHUD.target = self;
    itemHUD.state = s.nowPlayingHUDEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [fxMenu addItem:itemHUD];
    
    fxItem.submenu = fxMenu;
    [menu addItem:fxItem];
    
    // 9. Audio Source Submenu
    NSMenuItem *audioSourceItem = [[NSMenuItem alloc] initWithTitle:@"Audio Input Source" action:nil keyEquivalent:@""];
    NSMenu *sourceMenu = [[NSMenu alloc] initWithTitle:@"Audio Source"];
    NSArray *sourceNames = @[
        @"⚡ Native Internal System Audio (Pure Digital, No Mic)",
        @"🎵 Built-in Demo Beat Simulator (124 BPM)",
        @"🎤 Optional Microphone Input"
    ];
    for (NSInteger i = 0; i < sourceNames.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:sourceNames[i] action:@selector(selectAudioSource:) keyEquivalent:@""];
        item.tag = i;
        item.target = self;
        item.state = (s.audioSource == i) ? NSControlStateValueOn : NSControlStateValueOff;
        [sourceMenu addItem:item];
    }
    
    [sourceMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *authItem = [[NSMenuItem alloc] initWithTitle:@"⚙️ Open System Audio Permissions in Settings..." action:@selector(openSystemSettingsAuth:) keyEquivalent:@""];
    authItem.target = self;
    [sourceMenu addItem:authItem];
    
    audioSourceItem.submenu = sourceMenu;
    [menu addItem:audioSourceItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 10. Open Control Panel
    NSMenuItem *prefsItem = [[NSMenuItem alloc] initWithTitle:@"Open Control Panel..." action:@selector(showPreferencesWindow) keyEquivalent:@","];
    prefsItem.target = self;
    [menu addItem:prefsItem];
    
    // 11. System Audio Permission Button
    NSMenuItem *sysAuthItem = [[NSMenuItem alloc] initWithTitle:@"⚙️ Authorize System Audio in System Settings..." action:@selector(openSystemSettingsAuth:) keyEquivalent:@""];
    sysAuthItem.target = self;
    [menu addItem:sysAuthItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // 12. Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Decksi" action:@selector(quitApp:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    
    self.statusMenu = menu;
    self.statusItem.menu = menu;
}

- (void)updateMenuHeader {
    Settings *s = [Settings sharedSettings];
    if (self.trackInfoItem) {
        NSString *trackText = s.isMusicPlaying ? [NSString stringWithFormat:@"🎵 Playing: %@", s.currentTrackInfo] : @"🎵 Idle (Awaiting Music)";
        self.trackInfoItem.title = trackText;
    }
}

#pragma mark - Menu Actions

- (void)toggleBlackout:(id)sender {
    Settings *s = [Settings sharedSettings];
    s.blackoutMode = !s.blackoutMode;
    [s saveSettings];
    [[BorderOverlayController sharedController] updateVisibility];
    [self rebuildMenu];
}

- (void)toggleEnabled:(id)sender {
    Settings *s = [Settings sharedSettings];
    s.enabled = !s.enabled;
    [s saveSettings];
    [[BorderOverlayController sharedController] updateVisibility];
    [self rebuildMenu];
}

- (void)selectLyricsStyle:(NSMenuItem *)sender {
    [Settings sharedSettings].lyricsStyle = (LyricsStyle)sender.tag;
    [[Settings sharedSettings] saveSettings];
    [[BorderOverlayController sharedController] updateVisibility];
    [self rebuildMenu];
}

- (void)selectBorderDesign:(NSMenuItem *)sender {
    [Settings sharedSettings].borderDesign = (BorderDesign)sender.tag;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)selectPreset:(NSMenuItem *)sender {
    [Settings sharedSettings].preset = (LightingPreset)sender.tag;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)toggleWaves:(id)sender {
    [Settings sharedSettings].waveRipplesEnabled = ![Settings sharedSettings].waveRipplesEnabled;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)toggleParticles:(id)sender {
    [Settings sharedSettings].particlesEnabled = ![Settings sharedSettings].particlesEnabled;
    [ParticleEngine sharedEngine].enabled = [Settings sharedSettings].particlesEnabled;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)toggleShockwaves:(id)sender {
    [Settings sharedSettings].shockwavesEnabled = ![Settings sharedSettings].shockwavesEnabled;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)toggleHUD:(id)sender {
    [Settings sharedSettings].nowPlayingHUDEnabled = ![Settings sharedSettings].nowPlayingHUDEnabled;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)selectAudioSource:(NSMenuItem *)sender {
    if (sender.tag == 0) {
        // Trigger ScreenCapture access dialog if needed
        CGRequestScreenCaptureAccess();
    }
    [[AudioEngine sharedEngine] switchMode:sender.tag];
    [self rebuildMenu];
}

- (void)openSystemSettingsAuth:(id)sender {
    CGRequestScreenCaptureAccess();
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];
}

- (void)quitApp:(id)sender {
    [[BorderOverlayController sharedController] tearDownOverlayWindows];
    [[AudioEngine sharedEngine] stop];
    [NSApp terminate:nil];
}

#pragma mark - Preferences Control Panel Window

- (void)showPreferencesWindow {
    if (self.prefsWindow) {
        [self.prefsWindow makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }
    
    NSRect frame = NSMakeRect(0, 0, 520, 700);
    self.prefsWindow = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self.prefsWindow.title = @"Decksi — Control Panel";
    self.prefsWindow.delegate = self;
    [self.prefsWindow center];
    
    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    self.prefsWindow.contentView = contentView;
    
    Settings *s = [Settings sharedSettings];
    CGFloat y = 655;
    
    // Header Title
    NSTextField *titleLabel = [self makeLabelWithText:@"✨ Decksi — Ambient RGB & Lyrics" bold:YES size:17];
    titleLabel.frame = NSMakeRect(24, y, 470, 24);
    [contentView addSubview:titleLabel];
    
    y -= 42;
    // Blackout Mode Big Toggle Banner
    self.blackoutCheck = [self makeCheckBoxWithTitle:@"🌙 Turn ON Blackout Screen Mode (Pure Black Display + RGB + Lyrics)" state:s.blackoutMode action:@selector(blackoutCheckToggled:)];
    self.blackoutCheck.frame = NSMakeRect(24, y, 470, 22);
    self.blackoutCheck.font = [NSFont boldSystemFontOfSize:13];
    [contentView addSubview:self.blackoutCheck];
    
    y -= 26;
    self.lyricsCheck = [self makeCheckBoxWithTitle:@"Show Synchronized Lyrics in Blackout Mode" state:s.showLyricsInBlackout action:@selector(lyricsCheckToggled:)];
    self.lyricsCheck.frame = NSMakeRect(44, y, 400, 20);
    [contentView addSubview:self.lyricsCheck];
    
    y -= 38;
    // Lyrics Display Style Selector
    NSTextField *lLabel = [self makeLabelWithText:@"Lyrics Display Style:" bold:YES size:13];
    lLabel.frame = NSMakeRect(24, y, 160, 22);
    [contentView addSubview:lLabel];
    
    self.lyricsStylePopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(180, y - 2, 310, 26) pullsDown:NO];
    [self.lyricsStylePopUp addItemsWithTitles:@[
        @"🎤 Apple Music Focus (Active line centered + glow)",
        @"📄 Flowing 5-Line Teleprompter Sheet",
        @"💿 Split Vinyl Record & Lyrics Card",
        @"🌊 Minimalist Subtitles with Audio Waveform"
    ]];
    [self.lyricsStylePopUp selectItemAtIndex:s.lyricsStyle];
    self.lyricsStylePopUp.target = self;
    self.lyricsStylePopUp.action = @selector(lyricsStylePopUpChanged:);
    [contentView addSubview:self.lyricsStylePopUp];
    
    y -= 36;
    // Border Design Selector
    NSTextField *dLabel = [self makeLabelWithText:@"Border Design Style:" bold:YES size:13];
    dLabel.frame = NSMakeRect(24, y, 160, 22);
    [contentView addSubview:dLabel];
    
    self.borderDesignPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(180, y - 2, 310, 26) pullsDown:NO];
    [self.borderDesignPopUp addItemsWithTitles:@[
        @"✨ Classic Ambient Glow",
        @"📊 Equalizer Spectrum Bars",
        @"💡 WS2812B Dotted LED Strip",
        @"⚡ Cyber Circuit Tracks",
        @"💫 Double Neon Laser Rings",
        @"🌊 Liquid Wave Ribbon"
    ]];
    [self.borderDesignPopUp selectItemAtIndex:s.borderDesign];
    self.borderDesignPopUp.target = self;
    self.borderDesignPopUp.action = @selector(borderDesignPopUpChanged:);
    [contentView addSubview:self.borderDesignPopUp];
    
    y -= 38;
    // Border Width Slider
    NSTextField *wLabel = [self makeLabelWithText:@"Border Thickness:" bold:NO size:13];
    wLabel.frame = NSMakeRect(24, y, 220, 20);
    [contentView addSubview:wLabel];
    
    self.borderWidthLabel = [self makeLabelWithText:[NSString stringWithFormat:@"%.0f pt", s.borderWidth] bold:YES size:13];
    self.borderWidthLabel.frame = NSMakeRect(420, y, 70, 20);
    [contentView addSubview:self.borderWidthLabel];
    
    y -= 24;
    self.borderWidthSlider = [self makeSliderWithMin:4.0 max:36.0 value:s.borderWidth action:@selector(borderWidthChanged:)];
    self.borderWidthSlider.frame = NSMakeRect(24, y, 470, 20);
    [contentView addSubview:self.borderWidthSlider];
    
    y -= 36;
    // Glow Radius Slider
    NSTextField *gLabel = [self makeLabelWithText:@"Glow Blur Radius:" bold:NO size:13];
    gLabel.frame = NSMakeRect(24, y, 220, 20);
    [contentView addSubview:gLabel];
    
    self.glowRadiusLabel = [self makeLabelWithText:[NSString stringWithFormat:@"%.0f pt", s.glowRadius] bold:YES size:13];
    self.glowRadiusLabel.frame = NSMakeRect(420, y, 70, 20);
    [contentView addSubview:self.glowRadiusLabel];
    
    y -= 24;
    self.glowRadiusSlider = [self makeSliderWithMin:10.0 max:80.0 value:s.glowRadius action:@selector(glowRadiusChanged:)];
    self.glowRadiusSlider.frame = NSMakeRect(24, y, 470, 20);
    [contentView addSubview:self.glowRadiusSlider];
    
    y -= 36;
    // Audio Sensitivity Slider
    NSTextField *sLabel = [self makeLabelWithText:@"Audio Sensitivity:" bold:NO size:13];
    sLabel.frame = NSMakeRect(24, y, 220, 20);
    [contentView addSubview:sLabel];
    
    self.sensitivityLabel = [self makeLabelWithText:[NSString stringWithFormat:@"%.1fx", s.sensitivity] bold:YES size:13];
    self.sensitivityLabel.frame = NSMakeRect(420, y, 70, 20);
    [contentView addSubview:self.sensitivityLabel];
    
    y -= 24;
    self.sensitivitySlider = [self makeSliderWithMin:0.4 max:2.6 value:s.sensitivity action:@selector(sensitivityChanged:)];
    self.sensitivitySlider.frame = NSMakeRect(24, y, 470, 20);
    [contentView addSubview:self.sensitivitySlider];
    
    y -= 36;
    // Beat Reactivity Slider
    NSTextField *rLabel = [self makeLabelWithText:@"Beat Kick Reactivity:" bold:NO size:13];
    rLabel.frame = NSMakeRect(24, y, 220, 20);
    [contentView addSubview:rLabel];
    
    self.reactivityLabel = [self makeLabelWithText:[NSString stringWithFormat:@"%.0f%%", s.reactivity * 100.0] bold:YES size:13];
    self.reactivityLabel.frame = NSMakeRect(420, y, 70, 20);
    [contentView addSubview:self.reactivityLabel];
    
    y -= 24;
    self.reactivitySlider = [self makeSliderWithMin:0.0 max:1.5 value:s.reactivity action:@selector(reactivityChanged:)];
    self.reactivitySlider.frame = NSMakeRect(24, y, 470, 20);
    [contentView addSubview:self.reactivitySlider];
    
    y -= 36;
    // FX Checkboxes
    self.particlesCheck = [self makeCheckBoxWithTitle:@"✨ Cosmic Sparkle Particles" state:s.particlesEnabled action:@selector(particlesCheckToggled:)];
    self.particlesCheck.frame = NSMakeRect(24, y, 220, 20);
    [contentView addSubview:self.particlesCheck];
    
    self.shockwavesCheck = [self makeCheckBoxWithTitle:@"💥 Corner Bass Shockwaves" state:s.shockwavesEnabled action:@selector(shockwavesCheckToggled:)];
    self.shockwavesCheck.frame = NSMakeRect(260, y, 220, 20);
    [contentView addSubview:self.shockwavesCheck];
    
    y -= 26;
    self.wavesCheck = [self makeCheckBoxWithTitle:@"🌊 Equalizer Wave Ripples" state:s.waveRipplesEnabled action:@selector(wavesCheckToggled:)];
    self.wavesCheck.frame = NSMakeRect(24, y, 220, 20);
    [contentView addSubview:self.wavesCheck];
    
    self.hudCheck = [self makeCheckBoxWithTitle:@"💊 Dynamic Island HUD Pill" state:s.nowPlayingHUDEnabled action:@selector(hudCheckToggled:)];
    self.hudCheck.frame = NSMakeRect(260, y, 220, 20);
    [contentView addSubview:self.hudCheck];
    
    y -= 44;
    // Real-time Audio Spectrum & Beat VU Meters
    NSTextField *vuLabel = [self makeLabelWithText:@"Live Music Spectrum:" bold:YES size:12];
    vuLabel.frame = NSMakeRect(24, y, 220, 18);
    [contentView addSubview:vuLabel];
    
    y -= 22;
    self.bassMeter = [self makeVUIndicator];
    self.bassMeter.frame = NSMakeRect(24, y, 106, 14);
    [contentView addSubview:self.bassMeter];
    
    self.midMeter = [self makeVUIndicator];
    self.midMeter.frame = NSMakeRect(144, y, 106, 14);
    [contentView addSubview:self.midMeter];
    
    self.highMeter = [self makeVUIndicator];
    self.highMeter.frame = NSMakeRect(264, y, 106, 14);
    [contentView addSubview:self.highMeter];
    
    self.beatMeter = [self makeVUIndicator];
    self.beatMeter.frame = NSMakeRect(384, y, 106, 14);
    [contentView addSubview:self.beatMeter];
    
    y -= 18;
    NSTextField *tBass = [self makeLabelWithText:@"BASS" bold:NO size:10];
    tBass.frame = NSMakeRect(60, y, 50, 16);
    [contentView addSubview:tBass];
    
    NSTextField *tMid = [self makeLabelWithText:@"MIDS" bold:NO size:10];
    tMid.frame = NSMakeRect(180, y, 50, 16);
    [contentView addSubview:tMid];
    
    NSTextField *tHigh = [self makeLabelWithText:@"HIGHS" bold:NO size:10];
    tHigh.frame = NSMakeRect(300, y, 50, 16);
    [contentView addSubview:tHigh];
    
    NSTextField *tBeat = [self makeLabelWithText:@"BEAT" bold:YES size:10];
    tBeat.frame = NSMakeRect(420, y, 50, 16);
    [contentView addSubview:tBeat];
    
    __weak typeof(self) weakSelf = self;
    self.meterTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf updateVUMeters];
    }];
    
    [self.prefsWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object == self.prefsWindow) {
        [self.meterTimer invalidate];
        self.meterTimer = nil;
        self.prefsWindow = nil;
    }
}

- (void)updateVUMeters {
    AudioEngine *ae = [AudioEngine sharedEngine];
    self.bassMeter.doubleValue = ae.currentBassLevel * 100.0;
    self.midMeter.doubleValue = ae.currentMidLevel * 100.0;
    self.highMeter.doubleValue = ae.currentHighLevel * 100.0;
    self.beatMeter.doubleValue = ae.currentBeatLevel * 100.0;
}

#pragma mark - Sliders & Checkbox Handlers

- (void)blackoutCheckToggled:(NSButton *)sender {
    [Settings sharedSettings].blackoutMode = (sender.state == NSControlStateValueOn);
    [[Settings sharedSettings] saveSettings];
    [[BorderOverlayController sharedController] updateVisibility];
    [self rebuildMenu];
}

- (void)lyricsCheckToggled:(NSButton *)sender {
    [Settings sharedSettings].showLyricsInBlackout = (sender.state == NSControlStateValueOn);
    [[Settings sharedSettings] saveSettings];
}

- (void)lyricsStylePopUpChanged:(NSPopUpButton *)sender {
    [Settings sharedSettings].lyricsStyle = (LyricsStyle)sender.indexOfSelectedItem;
    [[Settings sharedSettings] saveSettings];
    [[BorderOverlayController sharedController] updateVisibility];
    [self rebuildMenu];
}

- (void)borderDesignPopUpChanged:(NSPopUpButton *)sender {
    [Settings sharedSettings].borderDesign = (BorderDesign)sender.indexOfSelectedItem;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)borderWidthChanged:(NSSlider *)slider {
    [Settings sharedSettings].borderWidth = slider.doubleValue;
    self.borderWidthLabel.stringValue = [NSString stringWithFormat:@"%.0f pt", slider.doubleValue];
    [[Settings sharedSettings] saveSettings];
}

- (void)glowRadiusChanged:(NSSlider *)slider {
    [Settings sharedSettings].glowRadius = slider.doubleValue;
    self.glowRadiusLabel.stringValue = [NSString stringWithFormat:@"%.0f pt", slider.doubleValue];
    [[Settings sharedSettings] saveSettings];
}

- (void)sensitivityChanged:(NSSlider *)slider {
    [Settings sharedSettings].sensitivity = slider.doubleValue;
    self.sensitivityLabel.stringValue = [NSString stringWithFormat:@"%.1fx", slider.doubleValue];
    [[Settings sharedSettings] saveSettings];
}

- (void)reactivityChanged:(NSSlider *)slider {
    [Settings sharedSettings].reactivity = slider.doubleValue;
    self.reactivityLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", slider.doubleValue * 100.0];
    [[Settings sharedSettings] saveSettings];
}

- (void)particlesCheckToggled:(NSButton *)sender {
    [Settings sharedSettings].particlesEnabled = (sender.state == NSControlStateValueOn);
    [ParticleEngine sharedEngine].enabled = [Settings sharedSettings].particlesEnabled;
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)wavesCheckToggled:(NSButton *)sender {
    [Settings sharedSettings].waveRipplesEnabled = (sender.state == NSControlStateValueOn);
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)shockwavesCheckToggled:(NSButton *)sender {
    [Settings sharedSettings].shockwavesEnabled = (sender.state == NSControlStateValueOn);
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

- (void)hudCheckToggled:(NSButton *)sender {
    [Settings sharedSettings].nowPlayingHUDEnabled = (sender.state == NSControlStateValueOn);
    [[Settings sharedSettings] saveSettings];
    [self rebuildMenu];
}

#pragma mark - UI Helpers

- (NSTextField *)makeLabelWithText:(NSString *)text bold:(BOOL)bold size:(CGFloat)size {
    NSTextField *lbl = [[NSTextField alloc] init];
    lbl.stringValue = text;
    lbl.editable = NO;
    lbl.selectable = NO;
    lbl.bordered = NO;
    lbl.backgroundColor = [NSColor clearColor];
    lbl.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    return lbl;
}

- (NSSlider *)makeSliderWithMin:(CGFloat)min max:(CGFloat)max value:(CGFloat)value action:(SEL)action {
    NSSlider *slider = [[NSSlider alloc] init];
    slider.minValue = min;
    slider.maxValue = max;
    slider.doubleValue = value;
    slider.continuous = YES;
    slider.target = self;
    slider.action = action;
    return slider;
}

- (NSButton *)makeCheckBoxWithTitle:(NSString *)title state:(BOOL)state action:(SEL)action {
    NSButton *btn = [NSButton checkboxWithTitle:title target:self action:action];
    btn.state = state ? NSControlStateValueOn : NSControlStateValueOff;
    return btn;
}

- (NSProgressIndicator *)makeVUIndicator {
    NSProgressIndicator *pi = [[NSProgressIndicator alloc] init];
    pi.minValue = 0.0;
    pi.maxValue = 100.0;
    pi.doubleValue = 0.0;
    pi.indeterminate = NO;
    pi.style = NSProgressIndicatorStyleBar;
    return pi;
}

@end
