#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, LightingPreset) {
    LightingPresetPrismRainbow = 0,
    LightingPresetCyberpunkNeon = 1,
    LightingPresetSunsetEmber = 2,
    LightingPresetAuroraBorealis = 3,
    LightingPresetSolarPlasma = 4,
    LightingPresetToxicMatrix = 5,
    LightingPresetSynthwave = 6,
    LightingPresetMusicSync = 7,
    LightingPresetPureHalo = 8,
    LightingPresetVideoAmbilight = 9   // 🎬 Real-time Screen Video Ambilight Sync
};

typedef NS_ENUM(NSInteger, EdgeLightingMode) {
    EdgeLightingModeAll = 0,
    EdgeLightingModeSides = 1,
    EdgeLightingModeTopBottom = 2,
    EdgeLightingModeCorners = 3
};

typedef NS_ENUM(NSInteger, BorderDesign) {
    BorderDesignClassicGlow = 0,       // Smooth luminous gradient falloff
    BorderDesignEqualizerBars = 1,     // Soundboard spectrum EQ visualizer bars
    BorderDesignDottedLEDStrip = 2,    // Physical WS2812B addressable LED nodes
    BorderDesignCyberCircuit = 3,      // Cyberpunk circuit traces & data pulses
    BorderDesignDoubleLaser = 4,       // Dual concentric neon laser rings
    BorderDesignWaveRibbon = 5         // Living undulating audio wave ribbon
};

typedef NS_ENUM(NSInteger, LyricsStyle) {
    LyricsStyleKaraokeFocus = 0,       // 🏛️ Classical 3D Amphitheater (Angled Horizon & Marble Reflection)
    LyricsStyleTeleprompter = 1,       // 🎭 Grand Opera House Stage (Theatrical Spotlights & Roman Serifs)
    LyricsStyleVinylSplit = 2,         // 💿 Oblique 3D Turntable Lounge (Tilted Vinyl & Gilded Plaque)
    LyricsStyleMinimalSubtitles = 3    // 🎼 Tilted 3D Chamber Manuscript (Acoustic Strings & Gold Trim)
};

typedef NS_ENUM(NSInteger, AudioSourceMode) {
    AudioSourceModeSystemInternal = 0,    // Pure internal macOS system audio (NO microphone)
    AudioSourceModeDemoSimulator = 1,     // Built-in 124 BPM simulated beat
    AudioSourceModeMicrophone = 2         // Optional physical microphone input
};

@interface Settings : NSObject

+ (instancetype)sharedSettings;

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) LightingPreset preset;
@property (nonatomic, assign) EdgeLightingMode edgeMode;
@property (nonatomic, assign) BorderDesign borderDesign;
@property (nonatomic, assign) LyricsStyle lyricsStyle;
@property (nonatomic, assign) AudioSourceMode audioSource;

// Blackout & Lyrics Mode
@property (nonatomic, assign) BOOL blackoutMode;            // Screen turns deep black, leaves only RGB + Lyrics
@property (nonatomic, assign) BOOL showLyricsInBlackout;    // Show synchronized lyrics in center

// Sliders & Adjustments
@property (nonatomic, assign) CGFloat borderWidth;          // 4.0 - 36.0 (default 14.0)
@property (nonatomic, assign) CGFloat glowRadius;           // 10.0 - 80.0 (default 40.0)
@property (nonatomic, assign) CGFloat sensitivity;          // 0.5 - 2.5 (default 1.2)
@property (nonatomic, assign) CGFloat reactivity;           // 0.0 - 1.5 (default 0.8)
@property (nonatomic, assign) CGFloat animationSpeed;       // 0.2 - 3.0 (default 1.0)
@property (nonatomic, assign) CGFloat cornerRadius;         // (default 14.0)

// Cool FX Toggles & Modifiers
@property (nonatomic, assign) BOOL waveRipplesEnabled;
@property (nonatomic, assign) CGFloat waveAmplitude;
@property (nonatomic, assign) BOOL particlesEnabled;
@property (nonatomic, assign) NSInteger particleCount;
@property (nonatomic, assign) BOOL shockwavesEnabled;
@property (nonatomic, assign) BOOL nowPlayingHUDEnabled;
@property (nonatomic, assign) BOOL videoLightSyncEnabled;       // 🎬 Cinema Ambilight: dynamically match video screen colors
@property (nonatomic, assign) CGFloat videoSaturationBoost;     // 1.0 - 2.0 (default 1.35)

// Dynamic Track State
@property (nonatomic, strong) NSArray<NSColor *> *trackColors;
@property (nonatomic, strong) NSString *currentTrackInfo;
@property (nonatomic, assign) BOOL isMusicPlaying;
@property (nonatomic, assign) NSTimeInterval currentTrackDuration;

- (void)saveSettings;
- (void)loadSettings;

@end
