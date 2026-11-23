#import "Settings.h"

static NSString *const kPrefEnabled            = @"Decksi_Enabled";
static NSString *const kPrefPreset             = @"Decksi_Preset";
static NSString *const kPrefEdgeMode           = @"Decksi_EdgeMode";
static NSString *const kPrefBorderDesign       = @"Decksi_BorderDesign";
static NSString *const kPrefLyricsStyle        = @"Decksi_LyricsStyle";
static NSString *const kPrefAudioSource        = @"Decksi_AudioSource_v3";
static NSString *const kPrefBlackoutMode       = @"Decksi_BlackoutMode";
static NSString *const kPrefShowLyrics         = @"Decksi_ShowLyrics";

static NSString *const kPrefBorderWidth        = @"Decksi_BorderWidth";
static NSString *const kPrefGlowRadius         = @"Decksi_GlowRadius";
static NSString *const kPrefSensitivity        = @"Decksi_Sensitivity";
static NSString *const kPrefReactivity         = @"Decksi_Reactivity";
static NSString *const kPrefAnimationSpeed     = @"Decksi_AnimationSpeed";
static NSString *const kPrefCornerRadius       = @"Decksi_CornerRadius";

static NSString *const kPrefWaveRipples        = @"Decksi_WaveRipples";
static NSString *const kPrefWaveAmplitude      = @"Decksi_WaveAmplitude";
static NSString *const kPrefParticles          = @"Decksi_Particles";
static NSString *const kPrefParticleCount      = @"Decksi_ParticleCount";
static NSString *const kPrefShockwaves         = @"Decksi_Shockwaves";
static NSString *const kPrefNowPlayingHUD      = @"Decksi_NowPlayingHUD";
static NSString *const kPrefVideoLightSync     = @"Decksi_VideoLightSync";
static NSString *const kPrefVideoSatBoost      = @"Decksi_VideoSatBoost";

@implementation Settings

+ (instancetype)sharedSettings {
    static Settings *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[Settings alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadSettings];
        _isMusicPlaying = NO;
        _currentTrackInfo = @"No music playing";
        _currentTrackDuration = 180.0;
        _trackColors = @[
            [NSColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0],
            [NSColor colorWithRed:1.0 green:0.1 blue:0.6 alpha:1.0]
        ];
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    _enabled = [defs objectForKey:kPrefEnabled] ? [defs boolForKey:kPrefEnabled] : YES;
    _preset = [defs objectForKey:kPrefPreset] ? [defs integerForKey:kPrefPreset] : LightingPresetPrismRainbow;
    _edgeMode = [defs objectForKey:kPrefEdgeMode] ? [defs integerForKey:kPrefEdgeMode] : EdgeLightingModeAll;
    _borderDesign = [defs objectForKey:kPrefBorderDesign] ? [defs integerForKey:kPrefBorderDesign] : BorderDesignClassicGlow;
    _lyricsStyle = [defs objectForKey:kPrefLyricsStyle] ? [defs integerForKey:kPrefLyricsStyle] : LyricsStyleKaraokeFocus;
    _audioSource = [defs objectForKey:kPrefAudioSource] ? [defs integerForKey:kPrefAudioSource] : AudioSourceModeSystemInternal;
    
    _blackoutMode = [defs objectForKey:kPrefBlackoutMode] ? [defs boolForKey:kPrefBlackoutMode] : NO;
    _showLyricsInBlackout = [defs objectForKey:kPrefShowLyrics] ? [defs boolForKey:kPrefShowLyrics] : YES;
    
    _borderWidth = [defs objectForKey:kPrefBorderWidth] ? [defs doubleForKey:kPrefBorderWidth] : 14.0;
    _glowRadius = [defs objectForKey:kPrefGlowRadius] ? [defs doubleForKey:kPrefGlowRadius] : 40.0;
    _sensitivity = [defs objectForKey:kPrefSensitivity] ? [defs doubleForKey:kPrefSensitivity] : 1.2;
    _reactivity = [defs objectForKey:kPrefReactivity] ? [defs doubleForKey:kPrefReactivity] : 0.8;
    _animationSpeed = [defs objectForKey:kPrefAnimationSpeed] ? [defs doubleForKey:kPrefAnimationSpeed] : 1.0;
    _cornerRadius = [defs objectForKey:kPrefCornerRadius] ? [defs doubleForKey:kPrefCornerRadius] : 14.0;
    
    _waveRipplesEnabled = [defs objectForKey:kPrefWaveRipples] ? [defs boolForKey:kPrefWaveRipples] : YES;
    _waveAmplitude = [defs objectForKey:kPrefWaveAmplitude] ? [defs doubleForKey:kPrefWaveAmplitude] : 1.0;
    _particlesEnabled = [defs objectForKey:kPrefParticles] ? [defs boolForKey:kPrefParticles] : YES;
    _particleCount = [defs objectForKey:kPrefParticleCount] ? [defs integerForKey:kPrefParticleCount] : 45;
    _shockwavesEnabled = [defs objectForKey:kPrefShockwaves] ? [defs boolForKey:kPrefShockwaves] : YES;
    _nowPlayingHUDEnabled = [defs objectForKey:kPrefNowPlayingHUD] ? [defs boolForKey:kPrefNowPlayingHUD] : YES;
    _videoLightSyncEnabled = [defs objectForKey:kPrefVideoLightSync] ? [defs boolForKey:kPrefVideoLightSync] : NO;
    _videoSaturationBoost = [defs objectForKey:kPrefVideoSatBoost] ? [defs doubleForKey:kPrefVideoSatBoost] : 1.35;
}

- (void)saveSettings {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setBool:_enabled forKey:kPrefEnabled];
    [defs setInteger:_preset forKey:kPrefPreset];
    [defs setInteger:_edgeMode forKey:kPrefEdgeMode];
    [defs setInteger:_borderDesign forKey:kPrefBorderDesign];
    [defs setInteger:_lyricsStyle forKey:kPrefLyricsStyle];
    [defs setInteger:_audioSource forKey:kPrefAudioSource];
    [defs setBool:_blackoutMode forKey:kPrefBlackoutMode];
    [defs setBool:_showLyricsInBlackout forKey:kPrefShowLyrics];
    
    [defs setDouble:_borderWidth forKey:kPrefBorderWidth];
    [defs setDouble:_glowRadius forKey:kPrefGlowRadius];
    [defs setDouble:_sensitivity forKey:kPrefSensitivity];
    [defs setDouble:_reactivity forKey:kPrefReactivity];
    [defs setDouble:_animationSpeed forKey:kPrefAnimationSpeed];
    [defs setDouble:_cornerRadius forKey:kPrefCornerRadius];
    
    [defs setBool:_waveRipplesEnabled forKey:kPrefWaveRipples];
    [defs setDouble:_waveAmplitude forKey:kPrefWaveAmplitude];
    [defs setBool:_particlesEnabled forKey:kPrefParticles];
    [defs setInteger:_particleCount forKey:kPrefParticleCount];
    [defs setBool:_shockwavesEnabled forKey:kPrefShockwaves];
    [defs setBool:_nowPlayingHUDEnabled forKey:kPrefNowPlayingHUD];
    [defs setBool:_videoLightSyncEnabled forKey:kPrefVideoLightSync];
    [defs setDouble:_videoSaturationBoost forKey:kPrefVideoSatBoost];
    [defs synchronize];
}

@end
