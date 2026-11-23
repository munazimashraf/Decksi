#import "BorderGlowView.h"
#import "Settings.h"
#import "AudioEngine.h"
#import "MusicDetector.h"
#import "LyricsManager.h"
#import <QuartzCore/QuartzCore.h>

@interface BorderGlowView () {
    // GPU Edge Glow Layers
    CAGradientLayer *_bottomGlow;
    CAGradientLayer *_bottomMask;
    CAGradientLayer *_topGlow;
    CAGradientLayer *_topMask;
    CAGradientLayer *_leftGlow;
    CAGradientLayer *_leftMask;
    CAGradientLayer *_rightGlow;
    CAGradientLayer *_rightMask;
    
    // Laser Bezel Layer
    CAShapeLayer *_bezelLayer;
    
    // Specialized Design Layer (Equalizer bars, Dotted LEDs, Cyber Circuit, Double Laser)
    CAShapeLayer *_designLayer;
    
    // Corner Shockwave Layer
    CAShapeLayer *_shockwaveLayer;
    
    // Blackout & Lyrics Layers
    CALayer *_blackoutLayer;
    CALayer *_lyricsContainer;
    CAGradientLayer *_vinylHalo;
    
    // Multi-line teleprompter text layer pool (up to 7 lines)
    CATextLayer *_lyricsTextLayers[7];
    CATextLayer *_reflectionTextLayers[3];
    CATextLayer *_infoTextLayer;
    CATextLayer *_hintTextLayer;
    CAShapeLayer *_waveformLayer;
    CAShapeLayer *_progressBarLayer;
    
    // Classical 3D View Angle Elements
    CAShapeLayer *_turntableDeck;
    CAShapeLayer *_turntableTonearm;
    CALayer *_lyricsPlaqueCard;
    CAGradientLayer *_spotlightLeft;
    CAGradientLayer *_spotlightRight;
    CAShapeLayer *_classicalOrnamentLayer;
    
    // GPU Sparkle Particles
    NSMutableArray<CALayer *> *_particleLayers;
    CGPoint _particleVelocities[30];
    CGFloat _particleLifes[30];
    CGFloat _particleDecays[30];
}

@property (nonatomic, assign) CGFloat phase;
@property (nonatomic, assign) CGFloat breathPhase;
@property (nonatomic, assign) CGFloat shockwaveRadius;
@property (nonatomic, assign) CGFloat shockwaveAlpha;
@property (nonatomic, assign) CGFloat vinylAngle;

@end

@implementation BorderGlowView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.drawsAsynchronously = YES;
        _phase = 0.0;
        _breathPhase = 0.0;
        _shockwaveRadius = 0.0;
        _shockwaveAlpha = 0.0;
        _vinylAngle = 0.0;
        
        [self setupGPULayers];
    }
    return self;
}

- (BOOL)isOpaque {
    return NO;
}

- (void)setupGPULayers {
    CALayer *root = self.layer;
    root.masksToBounds = YES;
    
    // 1. Blackout Layer
    _blackoutLayer = [CALayer layer];
    _blackoutLayer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
    _blackoutLayer.opacity = 0.0;
    [root addSublayer:_blackoutLayer];
    
    // 2. Lyrics Container Layer with 3D Perspective Vanishing Point
    _lyricsContainer = [CALayer layer];
    _lyricsContainer.opacity = 0.0;
    CATransform3D perspective = CATransform3DIdentity;
    perspective.m34 = -1.0 / 800.0; // Real 3D depth perspective!
    _lyricsContainer.sublayerTransform = perspective;
    [root addSublayer:_lyricsContainer];
    
    // Theatrical Volumetric Spotlights (Grand Opera)
    _spotlightLeft = [CAGradientLayer layer];
    _spotlightLeft.startPoint = CGPointMake(0.0, 1.0);
    _spotlightLeft.endPoint = CGPointMake(0.65, 0.0);
    _spotlightLeft.opacity = 0.0;
    [_lyricsContainer addSublayer:_spotlightLeft];
    
    _spotlightRight = [CAGradientLayer layer];
    _spotlightRight.startPoint = CGPointMake(1.0, 1.0);
    _spotlightRight.endPoint = CGPointMake(0.35, 0.0);
    _spotlightRight.opacity = 0.0;
    [_lyricsContainer addSublayer:_spotlightRight];
    
    // 3D Plaque Card (Frosted Obsidian with Gilded Gold Rim)
    _lyricsPlaqueCard = [CALayer layer];
    _lyricsPlaqueCard.backgroundColor = [NSColor colorWithWhite:0.04 alpha:0.80].CGColor;
    _lyricsPlaqueCard.borderColor = [NSColor colorWithRed:0.90 green:0.75 blue:0.40 alpha:0.65].CGColor;
    _lyricsPlaqueCard.borderWidth = 1.5;
    _lyricsPlaqueCard.cornerRadius = 20.0;
    _lyricsPlaqueCard.shadowColor = [NSColor blackColor].CGColor;
    _lyricsPlaqueCard.shadowOpacity = 0.85;
    _lyricsPlaqueCard.shadowRadius = 24.0;
    _lyricsPlaqueCard.opacity = 0.0;
    [_lyricsContainer addSublayer:_lyricsPlaqueCard];
    
    // 3D Oblique Turntable Deck & Tonearm
    _turntableDeck = [CAShapeLayer layer];
    _turntableDeck.fillColor = [NSColor clearColor].CGColor;
    _turntableDeck.opacity = 0.0;
    [_lyricsContainer addSublayer:_turntableDeck];
    
    _turntableTonearm = [CAShapeLayer layer];
    _turntableTonearm.fillColor = [NSColor clearColor].CGColor;
    _turntableTonearm.strokeColor = [NSColor colorWithRed:0.95 green:0.80 blue:0.45 alpha:0.90].CGColor;
    _turntableTonearm.lineWidth = 3.0;
    _turntableTonearm.lineCap = kCALineCapRound;
    _turntableTonearm.opacity = 0.0;
    [_lyricsContainer addSublayer:_turntableTonearm];
    
    _vinylHalo = [CAGradientLayer layer];
    _vinylHalo.type = kCAGradientLayerRadial;
    _vinylHalo.startPoint = CGPointMake(0.5, 0.5);
    _vinylHalo.endPoint = CGPointMake(1.0, 1.0);
    [_lyricsContainer addSublayer:_vinylHalo];
    
    // Classical Filigree & Ornament Layer
    _classicalOrnamentLayer = [CAShapeLayer layer];
    _classicalOrnamentLayer.fillColor = [NSColor clearColor].CGColor;
    _classicalOrnamentLayer.strokeColor = [NSColor colorWithRed:0.92 green:0.78 blue:0.42 alpha:0.75].CGColor;
    _classicalOrnamentLayer.lineWidth = 1.2;
    _classicalOrnamentLayer.opacity = 0.0;
    [_lyricsContainer addSublayer:_classicalOrnamentLayer];
    
    // Marble Floor Reflection Text Layers (for 3D Perspective Hall)
    for (int i = 0; i < 3; i++) {
        _reflectionTextLayers[i] = [self makeClassicalTextLayerWithSize:24.0 bold:YES italic:NO color:[NSColor whiteColor]];
        _reflectionTextLayers[i].opacity = 0.0;
        [_lyricsContainer addSublayer:_reflectionTextLayers[i]];
    }
    
    // Teleprompter / Lyrics Line Layers (7 lines in Classical Serif)
    for (int i = 0; i < 7; i++) {
        _lyricsTextLayers[i] = [self makeClassicalTextLayerWithSize:22.0 bold:NO italic:NO color:[NSColor whiteColor]];
        [_lyricsContainer addSublayer:_lyricsTextLayers[i]];
    }
    
    // Waveform line for minimal subtitles
    _waveformLayer = [CAShapeLayer layer];
    _waveformLayer.lineWidth = 2.0;
    _waveformLayer.fillColor = [NSColor clearColor].CGColor;
    [_lyricsContainer addSublayer:_waveformLayer];
    
    // Progress Bar Layer
    _progressBarLayer = [CAShapeLayer layer];
    _progressBarLayer.lineWidth = 2.5;
    _progressBarLayer.fillColor = [NSColor clearColor].CGColor;
    [_lyricsContainer addSublayer:_progressBarLayer];
    
    _infoTextLayer = [self makeTextLayerWithSize:13.5 bold:YES color:[NSColor colorWithWhite:0.80 alpha:0.95]];
    [_lyricsContainer addSublayer:_infoTextLayer];
    
    _hintTextLayer = [self makeTextLayerWithSize:11.0 bold:NO color:[NSColor colorWithWhite:0.40 alpha:0.75]];
    _hintTextLayer.string = @"Press ESC to exit  •  Press TAB to switch Lyrics Style";
    [_lyricsContainer addSublayer:_hintTextLayer];
    
    // Mask color arrays
    NSArray *maskColors = @[
        (__bridge id)[NSColor whiteColor].CGColor,
        (__bridge id)[NSColor colorWithWhite:1.0 alpha:0.4].CGColor,
        (__bridge id)[NSColor clearColor].CGColor
    ];
    NSArray *maskLocations = @[@0.0, @0.35, @1.0];
    
    // 3. Edge Glow Layers
    _bottomGlow = [CAGradientLayer layer];
    _bottomGlow.startPoint = CGPointMake(0.0, 0.5);
    _bottomGlow.endPoint = CGPointMake(1.0, 0.5);
    _bottomMask = [CAGradientLayer layer];
    _bottomMask.startPoint = CGPointMake(0.5, 0.0);
    _bottomMask.endPoint = CGPointMake(0.5, 1.0);
    _bottomMask.colors = maskColors;
    _bottomMask.locations = maskLocations;
    _bottomGlow.mask = _bottomMask;
    [root addSublayer:_bottomGlow];
    
    _topGlow = [CAGradientLayer layer];
    _topGlow.startPoint = CGPointMake(0.0, 0.5);
    _topGlow.endPoint = CGPointMake(1.0, 0.5);
    _topMask = [CAGradientLayer layer];
    _topMask.startPoint = CGPointMake(0.5, 1.0);
    _topMask.endPoint = CGPointMake(0.5, 0.0);
    _topMask.colors = maskColors;
    _topMask.locations = maskLocations;
    _topGlow.mask = _topMask;
    [root addSublayer:_topGlow];
    
    _leftGlow = [CAGradientLayer layer];
    _leftGlow.startPoint = CGPointMake(0.5, 1.0);
    _leftGlow.endPoint = CGPointMake(0.5, 0.0);
    _leftMask = [CAGradientLayer layer];
    _leftMask.startPoint = CGPointMake(0.0, 0.5);
    _leftMask.endPoint = CGPointMake(1.0, 0.5);
    _leftMask.colors = maskColors;
    _leftMask.locations = maskLocations;
    _leftGlow.mask = _leftMask;
    [root addSublayer:_leftGlow];
    
    _rightGlow = [CAGradientLayer layer];
    _rightGlow.startPoint = CGPointMake(0.5, 0.0);
    _rightGlow.endPoint = CGPointMake(0.5, 1.0);
    _rightMask = [CAGradientLayer layer];
    _rightMask.startPoint = CGPointMake(1.0, 0.5);
    _rightMask.endPoint = CGPointMake(0.0, 0.5);
    _rightMask.colors = maskColors;
    _rightMask.locations = maskLocations;
    _rightGlow.mask = _rightMask;
    [root addSublayer:_rightGlow];
    
    // 4. Specialized Design Layer
    _designLayer = [CAShapeLayer layer];
    _designLayer.fillColor = [NSColor clearColor].CGColor;
    _designLayer.lineCap = kCALineCapRound;
    _designLayer.lineJoin = kCALineJoinRound;
    _designLayer.opacity = 0.0;
    [root addSublayer:_designLayer];
    
    // 5. Bezel Laser Layer
    _bezelLayer = [CAShapeLayer layer];
    _bezelLayer.fillColor = [NSColor clearColor].CGColor;
    _bezelLayer.strokeColor = [NSColor colorWithWhite:1.0 alpha:0.25].CGColor;
    _bezelLayer.lineWidth = 1.6;
    [root addSublayer:_bezelLayer];
    
    // 6. Corner Shockwave Layer
    _shockwaveLayer = [CAShapeLayer layer];
    _shockwaveLayer.fillColor = [NSColor clearColor].CGColor;
    _shockwaveLayer.lineWidth = 3.0;
    _shockwaveLayer.opacity = 0.0;
    [root addSublayer:_shockwaveLayer];
    
    // 7. GPU Sparkle Particles
    _particleLayers = [NSMutableArray arrayWithCapacity:30];
    for (int i = 0; i < 30; i++) {
        CALayer *pl = [CALayer layer];
        pl.cornerRadius = 2.0;
        pl.opacity = 0.0;
        pl.backgroundColor = CGColorGetConstantColor(kCGColorWhite);
        [root addSublayer:pl];
        [_particleLayers addObject:pl];
        _particleLifes[i] = 0.0;
        _particleDecays[i] = 0.02;
    }
}

- (CATextLayer *)makeClassicalTextLayerWithSize:(CGFloat)size bold:(BOOL)bold italic:(BOOL)italic color:(NSColor *)color {
    CATextLayer *tl = [CATextLayer layer];
    tl.alignmentMode = kCAAlignmentCenter;
    tl.wrapped = NO;
    [self applyClassicalFontToLayer:tl size:size bold:bold italic:italic];
    tl.foregroundColor = color.CGColor;
    tl.contentsScale = [NSScreen mainScreen].backingScaleFactor ?: 2.0;
    return tl;
}

- (void)applyClassicalFontToLayer:(CATextLayer *)tl size:(CGFloat)size bold:(BOOL)bold italic:(BOOL)italic {
    NSString *fontName = bold ? @"Georgia-Bold" : (italic ? @"Georgia-Italic" : @"Georgia");
    NSFont *font = [NSFont fontWithName:fontName size:size];
    if (!font) font = [NSFont fontWithName:@"Palatino-Bold" size:size];
    if (!font) font = [NSFont systemFontOfSize:size weight:bold ? NSFontWeightBold : NSFontWeightRegular];
    tl.font = (__bridge CFTypeRef)font;
    tl.fontSize = size;
}

- (CATextLayer *)makeTextLayerWithSize:(CGFloat)size bold:(BOOL)bold color:(NSColor *)color {
    CATextLayer *tl = [CATextLayer layer];
    tl.alignmentMode = kCAAlignmentCenter;
    tl.wrapped = NO;
    tl.fontSize = size;
    tl.font = bold ? (__bridge CFTypeRef)[NSFont boldSystemFontOfSize:size] : (__bridge CFTypeRef)[NSFont systemFontOfSize:size];
    tl.foregroundColor = color.CGColor;
    tl.contentsScale = [NSScreen mainScreen].backingScaleFactor ?: 2.0;
    return tl;
}

#pragma mark - 60 FPS GPU Frame Tick

- (void)updateFrameRateTick {
    Settings *s = [Settings sharedSettings];
    if (!s.enabled) {
        if (self.layer.opacity > 0.0) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            self.layer.opacity = 0.0;
            [CATransaction commit];
        }
        return;
    }
    
    AudioEngine *ae = [AudioEngine sharedEngine];
    CGFloat speed = 0.0035 * s.animationSpeed * (1.0 + ae.currentMidLevel * 1.5 + ae.currentHighLevel * 0.8);
    _phase += speed;
    if (_phase > 1000.0) _phase = fmod(_phase, 1.0);
    _breathPhase += 0.04;
    _vinylAngle += 0.02 + ae.currentBassLevel * 0.025;
    
    // Advance lyrics timer
    [[LyricsManager sharedManager] tickTimeDelta:1.0 / 60.0];
    
    // Shockwave expansion
    if (ae.currentBeatLevel > 0.65 && s.shockwavesEnabled) {
        if (_shockwaveAlpha < 0.2) {
            _shockwaveAlpha = 0.85;
            _shockwaveRadius = s.borderWidth + 10.0;
        }
    }
    if (_shockwaveAlpha > 0.01) {
        _shockwaveRadius += 5.0;
        _shockwaveAlpha *= 0.90;
    } else {
        _shockwaveAlpha = 0.0;
    }
    
    // Begin 100% GPU Transaction (ZERO CPU Rasterization!)
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    self.layer.opacity = 1.0;
    CGRect bounds = self.bounds;
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;
    if (W <= 0 || H <= 0) {
        [CATransaction commit];
        return;
    }
    
    // 1. Blackout Mode Updates
    if (s.blackoutMode) {
        _blackoutLayer.opacity = 1.0;
        _blackoutLayer.frame = bounds;
        
        if (s.showLyricsInBlackout) {
            _lyricsContainer.opacity = 1.0;
            _lyricsContainer.frame = bounds;
            [self updateLyricsGPULayersInBounds:bounds];
        } else {
            _lyricsContainer.opacity = 0.0;
        }
    } else {
        _blackoutLayer.opacity = 0.0;
        _lyricsContainer.opacity = 0.0;
    }
    
    // Beat & Dynamics
    CGFloat beat = ae.currentBeatLevel;
    CGFloat bass = ae.currentBassLevel;
    CGFloat react = s.reactivity;
    
    CGFloat effectiveBorderWidth = s.borderWidth + (beat * 14.0 * react) + (bass * 6.0 * react);
    CGFloat effectiveGlowRadius = s.glowRadius + (beat * 28.0 * react) + (bass * 12.0 * react);
    CGFloat totalDepth = fmax(20.0, effectiveBorderWidth + effectiveGlowRadius);
    
    CGFloat baseAlpha = 0.88;
    CGFloat pulseAlpha = fmin(baseAlpha + beat * 0.12 * react, 1.0) + (sin(_breathPhase) * 0.5 + 0.5) * 0.06;
    
    // 2. Generate Color Palette Array for GPU Gradients (10 smooth interpolated stops)
    NSMutableArray *palette = [NSMutableArray arrayWithCapacity:10];
    for (int i = 0; i < 10; i++) {
        CGFloat prog = ((CGFloat)i / 10.0) + _phase;
        NSColor *col = [self colorAtNormalizedPosition:prog];
        [palette addObject:(__bridge id)[col colorWithAlphaComponent:pulseAlpha].CGColor];
    }
    
    // 3. Update GPU Edge Layers (ALWAYS ACTIVE & GLOWING!)
    BOOL renderBottom = (s.edgeMode == EdgeLightingModeAll || s.edgeMode == EdgeLightingModeTopBottom);
    BOOL renderTop    = (s.edgeMode == EdgeLightingModeAll || s.edgeMode == EdgeLightingModeTopBottom);
    BOOL renderLeft   = (s.edgeMode == EdgeLightingModeAll || s.edgeMode == EdgeLightingModeSides);
    BOOL renderRight  = (s.edgeMode == EdgeLightingModeAll || s.edgeMode == EdgeLightingModeSides);
    
    _bottomGlow.opacity = renderBottom ? 1.0 : 0.0;
    if (renderBottom) {
        _bottomGlow.frame = CGRectMake(0, 0, W, totalDepth);
        _bottomMask.frame = CGRectMake(0, 0, W, totalDepth);
        _bottomGlow.colors = palette;
    }
    
    _topGlow.opacity = renderTop ? 1.0 : 0.0;
    if (renderTop) {
        _topGlow.frame = CGRectMake(0, H - totalDepth, W, totalDepth);
        _topMask.frame = CGRectMake(0, 0, W, totalDepth);
        _topGlow.colors = palette;
    }
    
    _leftGlow.opacity = renderLeft ? 1.0 : 0.0;
    if (renderLeft) {
        _leftGlow.frame = CGRectMake(0, 0, totalDepth, H);
        _leftMask.frame = CGRectMake(0, 0, totalDepth, H);
        _leftGlow.colors = palette;
    }
    
    _rightGlow.opacity = renderRight ? 1.0 : 0.0;
    if (renderRight) {
        _rightGlow.frame = CGRectMake(W - totalDepth, 0, totalDepth, H);
        _rightMask.frame = CGRectMake(0, 0, totalDepth, H);
        _rightGlow.colors = palette;
    }
    
    // 4. Specialized Design Layer (Overlaid on top of ambient glow!)
    if (s.borderDesign != BorderDesignClassicGlow) {
        _designLayer.opacity = 1.0;
        _designLayer.frame = bounds;
        [self updateDesignShapeLayerInBounds:bounds depth:totalDepth bw:effectiveBorderWidth pulseAlpha:pulseAlpha];
    } else {
        _designLayer.opacity = 0.0;
    }
    
    // 5. Update Bezel Laser Contour
    if (s.borderWidth > 2.0) {
        _bezelLayer.opacity = 1.0;
        CGPathRef bPath = CGPathCreateWithRoundedRect(CGRectInset(bounds, effectiveBorderWidth * 0.35, effectiveBorderWidth * 0.35),
                                                      s.cornerRadius, s.cornerRadius, NULL);
        _bezelLayer.path = bPath;
        CGPathRelease(bPath);
    } else {
        _bezelLayer.opacity = 0.0;
    }
    
    // 6. Update Corner Shockwaves
    if (_shockwaveAlpha > 0.02 && s.shockwavesEnabled) {
        _shockwaveLayer.opacity = _shockwaveAlpha;
        _shockwaveLayer.strokeColor = (__bridge CGColorRef)palette[0];
        CGMutablePathRef swPath = CGPathCreateMutable();
        CGPoint c[4] = { CGPointMake(0,0), CGPointMake(W,0), CGPointMake(W,H), CGPointMake(0,H) };
        for (int i = 0; i < 4; i++) {
            CGPathAddArc(swPath, NULL, c[i].x, c[i].y, _shockwaveRadius, 0, M_PI * 2, 0);
        }
        _shockwaveLayer.path = swPath;
        CGPathRelease(swPath);
    } else {
        _shockwaveLayer.opacity = 0.0;
    }
    
    // 7. Update Fast GPU Particles
    if (s.particlesEnabled) {
        [self updateGPUParticlesInBounds:bounds bass:bass high:ae.currentHighLevel beat:beat];
    } else {
        for (CALayer *pl in _particleLayers) pl.opacity = 0.0;
    }
    
    [CATransaction commit];
}

#pragma mark - Specialized GPU Design Shapes

- (void)updateDesignShapeLayerInBounds:(CGRect)bounds depth:(CGFloat)depth bw:(CGFloat)bw pulseAlpha:(CGFloat)pulseAlpha {
    Settings *s = [Settings sharedSettings];
    AudioEngine *ae = [AudioEngine sharedEngine];
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;
    
    CGMutablePathRef path = CGPathCreateMutable();
    NSColor *neon = [self colorAtNormalizedPosition:_phase];
    
    switch (s.borderDesign) {
        case BorderDesignEqualizerBars: {
            _designLayer.strokeColor = [neon colorWithAlphaComponent:pulseAlpha].CGColor;
            _designLayer.lineWidth = 4.0;
            _designLayer.fillColor = [NSColor clearColor].CGColor;
            
            int bars = 40;
            CGFloat step = W / (CGFloat)bars;
            for (int i = 0; i < bars; i++) {
                CGFloat x = i * step + step * 0.5;
                CGFloat prog = (CGFloat)i / (CGFloat)bars;
                CGFloat wave = sin(prog * M_PI * 4.0 + _phase * 6.0) * 0.5 + 0.5;
                CGFloat barH = bw * 0.8 + wave * ae.currentBassLevel * 24.0 + ae.currentMidLevel * 14.0 + ae.currentBeatLevel * 12.0;
                
                // Bottom bar
                CGPathMoveToPoint(path, NULL, x, 0);
                CGPathAddLineToPoint(path, NULL, x, barH);
                // Top bar
                CGPathMoveToPoint(path, NULL, x, H);
                CGPathAddLineToPoint(path, NULL, x, H - barH);
            }
            break;
        }
        case BorderDesignDottedLEDStrip: {
            _designLayer.strokeColor = [neon colorWithAlphaComponent:pulseAlpha].CGColor;
            _designLayer.fillColor = [neon colorWithAlphaComponent:pulseAlpha].CGColor;
            _designLayer.lineWidth = 1.0;
            
            CGFloat spacing = 28.0;
            CGFloat r = fmax(3.0, bw * 0.35);
            for (CGFloat x = 14; x < W; x += spacing) {
                CGPathAddEllipseInRect(path, NULL, CGRectMake(x - r, bw * 0.6 - r, r * 2, r * 2));
                CGPathAddEllipseInRect(path, NULL, CGRectMake(x - r, H - bw * 0.6 - r, r * 2, r * 2));
            }
            for (CGFloat y = 14; y < H; y += spacing) {
                CGPathAddEllipseInRect(path, NULL, CGRectMake(bw * 0.6 - r, y - r, r * 2, r * 2));
                CGPathAddEllipseInRect(path, NULL, CGRectMake(W - bw * 0.6 - r, y - r, r * 2, r * 2));
            }
            break;
        }
        case BorderDesignCyberCircuit: {
            _designLayer.strokeColor = [neon colorWithAlphaComponent:pulseAlpha].CGColor;
            _designLayer.lineWidth = 2.4;
            _designLayer.fillColor = [NSColor clearColor].CGColor;
            
            CGFloat cSize = 120.0;
            CGPathMoveToPoint(path, NULL, bw, cSize);
            CGPathAddLineToPoint(path, NULL, bw, bw * 2);
            CGPathAddLineToPoint(path, NULL, bw * 2, bw);
            CGPathAddLineToPoint(path, NULL, cSize, bw);
            
            CGPathMoveToPoint(path, NULL, W - cSize, bw);
            CGPathAddLineToPoint(path, NULL, W - bw * 2, bw);
            CGPathAddLineToPoint(path, NULL, W - bw, bw * 2);
            CGPathAddLineToPoint(path, NULL, W - bw, cSize);
            
            CGPathMoveToPoint(path, NULL, W - bw, H - cSize);
            CGPathAddLineToPoint(path, NULL, W - bw, H - bw * 2);
            CGPathAddLineToPoint(path, NULL, W - bw * 2, H - bw);
            CGPathAddLineToPoint(path, NULL, W - cSize, H - bw);
            
            CGPathMoveToPoint(path, NULL, cSize, H - bw);
            CGPathAddLineToPoint(path, NULL, bw * 2, H - bw);
            CGPathAddLineToPoint(path, NULL, bw, H - bw * 2);
            CGPathAddLineToPoint(path, NULL, bw, H - cSize);
            break;
        }
        case BorderDesignDoubleLaser: {
            _designLayer.strokeColor = [neon colorWithAlphaComponent:pulseAlpha].CGColor;
            _designLayer.lineWidth = 2.0;
            _designLayer.fillColor = [NSColor clearColor].CGColor;
            
            CGPathAddRoundedRect(path, NULL, CGRectInset(bounds, bw * 0.4, bw * 0.4), s.cornerRadius, s.cornerRadius);
            CGPathAddRoundedRect(path, NULL, CGRectInset(bounds, bw * 1.5, bw * 1.5), s.cornerRadius * 0.8, s.cornerRadius * 0.8);
            break;
        }
        default:
            break;
    }
    
    _designLayer.path = path;
    CGPathRelease(path);
}

#pragma mark - GPU Fast Particles

- (void)updateGPUParticlesInBounds:(CGRect)bounds bass:(CGFloat)bass high:(CGFloat)high beat:(CGFloat)beat {
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;
    
    for (int i = 0; i < 30; i++) {
        CALayer *pl = _particleLayers[i];
        if (_particleLifes[i] <= 0.0) {
            if (arc4random_uniform(10) > 3) continue;
            int edge = arc4random_uniform(4);
            CGFloat pos = (CGFloat)arc4random_uniform(1000) / 1000.0;
            CGFloat speed = 1.0 + ((CGFloat)arc4random_uniform(100) / 100.0) * 2.0 + bass * 3.0;
            
            if (edge == 0) {
                pl.position = CGPointMake(pos * W, 2.0);
                _particleVelocities[i] = CGPointMake(0, speed);
            } else if (edge == 1) {
                pl.position = CGPointMake(W - 2.0, pos * H);
                _particleVelocities[i] = CGPointMake(-speed, 0);
            } else if (edge == 2) {
                pl.position = CGPointMake(pos * W, H - 2.0);
                _particleVelocities[i] = CGPointMake(0, -speed);
            } else {
                pl.position = CGPointMake(2.0, pos * H);
                _particleVelocities[i] = CGPointMake(speed, 0);
            }
            CGFloat sz = 3.0 + ((CGFloat)arc4random_uniform(100) / 100.0) * 3.5 + high * 2.0;
            pl.bounds = CGRectMake(0, 0, sz, sz);
            pl.cornerRadius = sz * 0.5;
            _particleLifes[i] = 1.0;
            _particleDecays[i] = 0.015 + ((CGFloat)arc4random_uniform(100) / 100.0) * 0.015;
            NSColor *c = [self colorAtNormalizedPosition:pos + _phase];
            pl.backgroundColor = c.CGColor;
            pl.opacity = 0.8;
        } else {
            CGPoint p = pl.position;
            p.x += _particleVelocities[i].x;
            p.y += _particleVelocities[i].y;
            pl.position = p;
            _particleLifes[i] -= _particleDecays[i];
            pl.opacity = _particleLifes[i] * 0.8 + (high * 0.2);
        }
    }
}

#pragma mark - Blackout Center Lyrics GPU Layers (Classical 3D Perspective View Angles!)

- (void)updateLyricsGPULayersInBounds:(CGRect)bounds {
    LyricsManager *lm = [LyricsManager sharedManager];
    Settings *s = [Settings sharedSettings];
    AudioEngine *ae = [AudioEngine sharedEngine];
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;
    CGFloat cy = H * 0.5;
    CGFloat maxW = W * 0.82;
    
    NSColor *trackCol = (s.trackColors.count > 0) ? s.trackColors[0] : [NSColor cyanColor];
    NSColor *goldCol = [NSColor colorWithRed:0.95 green:0.82 blue:0.45 alpha:1.0];
    NSColor *ivoryCol = [NSColor colorWithRed:0.98 green:0.96 blue:0.92 alpha:1.0];
    
    // Reset all layer states and transforms
    for (int i = 0; i < 7; i++) {
        _lyricsTextLayers[i].opacity = 0.0;
        _lyricsTextLayers[i].transform = CATransform3DIdentity;
        _lyricsTextLayers[i].alignmentMode = kCAAlignmentCenter;
    }
    for (int i = 0; i < 3; i++) {
        _reflectionTextLayers[i].opacity = 0.0;
        _reflectionTextLayers[i].transform = CATransform3DIdentity;
    }
    _vinylHalo.opacity = 0.0;
    _waveformLayer.opacity = 0.0;
    _progressBarLayer.opacity = 0.0;
    _spotlightLeft.opacity = 0.0;
    _spotlightRight.opacity = 0.0;
    _turntableDeck.opacity = 0.0;
    _turntableTonearm.opacity = 0.0;
    _lyricsPlaqueCard.opacity = 0.0;
    _classicalOrnamentLayer.opacity = 0.0;
    
    NSString *curr = lm.currentLine.length > 0 ? lm.currentLine : (s.currentTrackInfo.length > 0 ? s.currentTrackInfo : @"♪ Playing Classical Masterpiece ♪");
    
    // =========================================================================
    // STYLE 0: 🏛️ Classical 3D Amphitheater (Angled Horizon & Marble Floor Reflection)
    // =========================================================================
    if (s.lyricsStyle == LyricsStyleKaraokeFocus) {
        // Dramatic 3D Perspective vanishing backwards into the stage
        CATransform3D stageTilt = CATransform3DMakeRotation(28.0 * M_PI / 180.0, 1.0, 0.0, 0.0);
        
        // Classical Golden Halo
        _vinylHalo.opacity = 0.85;
        CGFloat vW = W * 0.65;
        CGFloat vH = 260.0;
        _vinylHalo.frame = CGRectMake((W - vW) * 0.5, cy - vH * 0.5 + 40.0, vW, vH);
        _vinylHalo.colors = @[
            (__bridge id)[goldCol colorWithAlphaComponent:0.22 + ae.currentBassLevel * 0.15].CGColor,
            (__bridge id)[trackCol colorWithAlphaComponent:0.10].CGColor,
            (__bridge id)[NSColor clearColor].CGColor
        ];
        
        // Ornate Filigree Crown above active lyric
        _classicalOrnamentLayer.opacity = 0.80;
        _classicalOrnamentLayer.strokeColor = goldCol.CGColor;
        CGMutablePathRef cPath = CGPathCreateMutable();
        CGFloat crownY = cy + 68.0;
        CGPathMoveToPoint(cPath, NULL, W * 0.5 - 120.0, crownY);
        CGPathAddLineToPoint(cPath, NULL, W * 0.5 - 20.0, crownY);
        // Diamond emblem in center
        CGPathMoveToPoint(cPath, NULL, W * 0.5, crownY + 8.0);
        CGPathAddLineToPoint(cPath, NULL, W * 0.5 + 8.0, crownY);
        CGPathAddLineToPoint(cPath, NULL, W * 0.5, crownY - 8.0);
        CGPathAddLineToPoint(cPath, NULL, W * 0.5 - 8.0, crownY);
        CGPathCloseSubpath(cPath);
        CGPathMoveToPoint(cPath, NULL, W * 0.5 + 20.0, crownY);
        CGPathAddLineToPoint(cPath, NULL, W * 0.5 + 120.0, crownY);
        _classicalOrnamentLayer.path = cPath;
        CGPathRelease(cPath);
        
        // Previous Line (receding upwards into depth)
        [self applyClassicalFontToLayer:_lyricsTextLayers[0] size:19.0 bold:NO italic:YES];
        _lyricsTextLayers[0].opacity = 0.40;
        _lyricsTextLayers[0].frame = CGRectMake((W - maxW) * 0.5, cy + 85.0, maxW, 30.0);
        _lyricsTextLayers[0].foregroundColor = [NSColor colorWithWhite:0.80 alpha:0.75].CGColor;
        _lyricsTextLayers[0].string = lm.previousLine ?: @"";
        _lyricsTextLayers[0].transform = CATransform3DConcat(stageTilt, CATransform3DMakeScale(0.88, 0.88, 1.0));
        
        // Active Line (Hero Grand Classical Serif in Full Foreground 3D Focus)
        [self applyClassicalFontToLayer:_lyricsTextLayers[1] size:36.0 bold:YES italic:NO];
        _lyricsTextLayers[1].opacity = 1.0;
        _lyricsTextLayers[1].frame = CGRectMake((W - maxW) * 0.5, cy - 14.0, maxW, 58.0);
        _lyricsTextLayers[1].foregroundColor = ivoryCol.CGColor;
        _lyricsTextLayers[1].string = curr;
        _lyricsTextLayers[1].shadowColor = goldCol.CGColor;
        _lyricsTextLayers[1].shadowOpacity = 0.95;
        _lyricsTextLayers[1].shadowRadius = 22.0 + ae.currentBassLevel * 12.0;
        CATransform3D heroTransform = CATransform3DConcat(stageTilt, CATransform3DMakeTranslation(0, 0, 40.0));
        _lyricsTextLayers[1].transform = CATransform3DConcat(heroTransform, CATransform3DMakeScale(1.12, 1.12, 1.0));
        
        // Polished Marble Floor Inverted Reflection
        [self applyClassicalFontToLayer:_reflectionTextLayers[0] size:36.0 bold:YES italic:NO];
        _reflectionTextLayers[0].opacity = 0.22 + ae.currentBassLevel * 0.10;
        _reflectionTextLayers[0].frame = CGRectMake((W - maxW) * 0.5, cy - 80.0, maxW, 58.0);
        _reflectionTextLayers[0].foregroundColor = [goldCol colorWithAlphaComponent:0.75].CGColor;
        _reflectionTextLayers[0].string = curr;
        CATransform3D reflTransform = CATransform3DConcat(stageTilt, CATransform3DMakeScale(1.08, -0.65, 1.0));
        _reflectionTextLayers[0].transform = reflTransform;
        
        // Next Line 1 (receding into distant horizon)
        [self applyClassicalFontToLayer:_lyricsTextLayers[2] size:19.0 bold:NO italic:YES];
        _lyricsTextLayers[2].opacity = 0.45;
        _lyricsTextLayers[2].frame = CGRectMake((W - maxW) * 0.5, cy - 110.0, maxW, 30.0);
        _lyricsTextLayers[2].foregroundColor = [NSColor colorWithWhite:0.80 alpha:0.75].CGColor;
        _lyricsTextLayers[2].string = lm.nextLine ?: @"";
        _lyricsTextLayers[2].transform = CATransform3DConcat(stageTilt, CATransform3DMakeScale(0.85, 0.85, 1.0));
        
        // Next Line 2 (deep vanishing point)
        NSArray<LyricLine *> *win = [lm linesWindowWithCount:5];
        if (win.count >= 4) {
            [self applyClassicalFontToLayer:_lyricsTextLayers[3] size:16.0 bold:NO italic:YES];
            _lyricsTextLayers[3].opacity = 0.25;
            _lyricsTextLayers[3].frame = CGRectMake((W - maxW) * 0.5, cy - 145.0, maxW, 26.0);
            _lyricsTextLayers[3].foregroundColor = [NSColor colorWithWhite:0.70 alpha:0.50].CGColor;
            _lyricsTextLayers[3].string = win[3].text;
            _lyricsTextLayers[3].transform = CATransform3DConcat(stageTilt, CATransform3DMakeScale(0.72, 0.72, 1.0));
        }
    }
    // =========================================================================
    // STYLE 1: 🎭 Grand Opera House Stage (Theatrical Volumetric Spotlights & Roman Serifs)
    // =========================================================================
    else if (s.lyricsStyle == LyricsStyleTeleprompter) {
        // Dramatic Angled Theatrical Spotlights Converging on Center
        _spotlightLeft.opacity = 0.75 + ae.currentMidLevel * 0.25;
        _spotlightLeft.frame = CGRectMake(0, cy - 40.0, W * 0.55, H * 0.60);
        _spotlightLeft.colors = @[
            (__bridge id)[NSColor colorWithRed:1.0 green:0.92 blue:0.70 alpha:0.28].CGColor,
            (__bridge id)[goldCol colorWithAlphaComponent:0.08].CGColor,
            (__bridge id)[NSColor clearColor].CGColor
        ];
        
        _spotlightRight.opacity = 0.75 + ae.currentMidLevel * 0.25;
        _spotlightRight.frame = CGRectMake(W * 0.45, cy - 40.0, W * 0.55, H * 0.60);
        _spotlightRight.colors = @[
            (__bridge id)[trackCol colorWithAlphaComponent:0.25].CGColor,
            (__bridge id)[goldCol colorWithAlphaComponent:0.08].CGColor,
            (__bridge id)[NSColor clearColor].CGColor
        ];
        
        // 5-Line Choral Stanza receding up and down
        NSArray<LyricLine *> *window = [lm linesWindowWithCount:5];
        CGFloat lineSpacing = 42.0;
        CGFloat startY = cy + (window.count * lineSpacing * 0.5) - 10.0;
        
        for (NSUInteger i = 0; i < window.count && i < 5; i++) {
            BOOL isActive = (lm.currentIndex >= 0 && i < window.count && [window[i].text isEqualToString:curr]);
            
            [self applyClassicalFontToLayer:_lyricsTextLayers[i] size:isActive ? 32.0 : 18.0 bold:isActive italic:!isActive];
            _lyricsTextLayers[i].opacity = isActive ? 1.0 : (0.35 + (2 - labs((NSInteger)i - 2)) * 0.08);
            _lyricsTextLayers[i].frame = CGRectMake((W - maxW) * 0.5, startY - (i * lineSpacing), maxW, isActive ? 46.0 : 32.0);
            _lyricsTextLayers[i].foregroundColor = isActive ? ivoryCol.CGColor : [NSColor colorWithWhite:0.75 alpha:0.70].CGColor;
            _lyricsTextLayers[i].string = window[i].text;
            
            if (isActive) {
                _lyricsTextLayers[i].shadowColor = goldCol.CGColor;
                _lyricsTextLayers[i].shadowOpacity = 0.95;
                _lyricsTextLayers[i].shadowRadius = 24.0 + ae.currentBassLevel * 14.0;
                CATransform3D activeTilt = CATransform3DMakeScale(1.10, 1.10, 1.0);
                _lyricsTextLayers[i].transform = CATransform3DConcat(CATransform3DMakeTranslation(0, 0, 30.0), activeTilt);
            } else {
                CGFloat zOff = -25.0 * fabs((CGFloat)i - 2.0);
                CGFloat scale = 1.0 - 0.08 * fabs((CGFloat)i - 2.0);
                _lyricsTextLayers[i].shadowOpacity = 0.0;
                _lyricsTextLayers[i].transform = CATransform3DConcat(CATransform3DMakeTranslation(0, 0, zOff), CATransform3DMakeScale(scale, scale, 1.0));
            }
        }
    }
    // =========================================================================
    // STYLE 2: 💿 Oblique 3D Turntable Lounge (Tilted Vinyl Deck & Gilded Manuscript Plaque)
    // =========================================================================
    else if (s.lyricsStyle == LyricsStyleVinylSplit) {
        CGFloat turntableCenterX = W * 0.30;
        CGFloat plaqueCenterX = W * 0.70;
        
        // 1. Oblique 3D Tilted Turntable Deck (Left Side)
        CATransform3D tTurntable = CATransform3DConcat(
            CATransform3DMakeRotation(52.0 * M_PI / 180.0, 1.0, 0.0, 0.0),
            CATransform3DMakeRotation(-24.0 * M_PI / 180.0, 0.0, 0.0, 1.0)
        );
        _turntableDeck.opacity = 1.0;
        _turntableDeck.transform = tTurntable;
        _turntableDeck.position = CGPointMake(turntableCenterX, cy);
        
        // Draw Grooved Concentric Vinyl Disc with Gold Center Label
        CGMutablePathRef vPath = CGPathCreateMutable();
        CGFloat rMax = 150.0 + ae.currentBassLevel * 10.0;
        // Outer vinyl edge
        CGPathAddEllipseInRect(vPath, NULL, CGRectMake(-rMax, -rMax, rMax * 2, rMax * 2));
        // Micro grooves
        for (CGFloat r = rMax - 18.0; r > 55.0; r -= 18.0) {
            CGPathAddEllipseInRect(vPath, NULL, CGRectMake(-r, -r, r * 2, r * 2));
        }
        // Center label rim
        CGPathAddEllipseInRect(vPath, NULL, CGRectMake(-45.0, -45.0, 90.0, 90.0));
        // Spindle hole
        CGPathAddEllipseInRect(vPath, NULL, CGRectMake(-8.0, -8.0, 16.0, 16.0));
        _turntableDeck.path = vPath;
        CGPathRelease(vPath);
        _turntableDeck.strokeColor = [goldCol colorWithAlphaComponent:0.40].CGColor;
        _turntableDeck.lineWidth = 1.2;
        
        // Tonearm resting on record
        _turntableTonearm.opacity = 1.0;
        _turntableTonearm.transform = tTurntable;
        _turntableTonearm.position = CGPointMake(turntableCenterX, cy);
        CGMutablePathRef armPath = CGPathCreateMutable();
        CGPathMoveToPoint(armPath, NULL, rMax + 25.0, -rMax + 30.0);
        CGPathAddLineToPoint(armPath, NULL, rMax - 10.0, -rMax + 70.0);
        CGPathAddLineToPoint(armPath, NULL, 30.0, 20.0); // Cartridge resting on groove
        _turntableTonearm.path = armPath;
        CGPathRelease(armPath);
        
        // Ambient vinyl glow halo
        _vinylHalo.opacity = 0.70;
        CGFloat vSize = 340.0;
        _vinylHalo.frame = CGRectMake(turntableCenterX - vSize * 0.5, cy - vSize * 0.5, vSize, vSize);
        _vinylHalo.colors = @[
            (__bridge id)[trackCol colorWithAlphaComponent:0.35].CGColor,
            (__bridge id)[goldCol colorWithAlphaComponent:0.15].CGColor,
            (__bridge id)[NSColor clearColor].CGColor
        ];
        
        // 2. Floating 3D Gilded Plaque (Right Side)
        CGFloat cardW = W * 0.46;
        CGFloat cardH = H * 0.55;
        CATransform3D tPlaque = CATransform3DConcat(
            CATransform3DMakeRotation(10.0 * M_PI / 180.0, 1.0, 0.0, 0.0),
            CATransform3DMakeRotation(-16.0 * M_PI / 180.0, 0.0, 1.0, 0.0)
        );
        _lyricsPlaqueCard.opacity = 1.0;
        _lyricsPlaqueCard.frame = CGRectMake(plaqueCenterX - cardW * 0.5, cy - cardH * 0.5, cardW, cardH);
        _lyricsPlaqueCard.transform = tPlaque;
        
        // Inside Plaque: Left-Aligned Classical Manuscript Typography
        CGFloat innerLeft = plaqueCenterX - cardW * 0.44;
        CGFloat innerW = cardW * 0.88;
        
        // Previous line
        [self applyClassicalFontToLayer:_lyricsTextLayers[0] size:18.0 bold:NO italic:YES];
        _lyricsTextLayers[0].opacity = 0.45;
        _lyricsTextLayers[0].alignmentMode = kCAAlignmentLeft;
        _lyricsTextLayers[0].frame = CGRectMake(innerLeft, cy + 50.0, innerW, 28.0);
        _lyricsTextLayers[0].foregroundColor = [NSColor colorWithWhite:0.80 alpha:0.75].CGColor;
        _lyricsTextLayers[0].string = lm.previousLine ?: @"";
        _lyricsTextLayers[0].transform = tPlaque;
        
        // Active line in luminous gold
        [self applyClassicalFontToLayer:_lyricsTextLayers[1] size:28.0 bold:YES italic:NO];
        _lyricsTextLayers[1].opacity = 1.0;
        _lyricsTextLayers[1].alignmentMode = kCAAlignmentLeft;
        _lyricsTextLayers[1].frame = CGRectMake(innerLeft, cy - 14.0, innerW, 48.0);
        _lyricsTextLayers[1].foregroundColor = ivoryCol.CGColor;
        _lyricsTextLayers[1].string = curr;
        _lyricsTextLayers[1].shadowColor = goldCol.CGColor;
        _lyricsTextLayers[1].shadowOpacity = 0.90;
        _lyricsTextLayers[1].shadowRadius = 18.0;
        _lyricsTextLayers[1].transform = CATransform3DConcat(tPlaque, CATransform3DMakeTranslation(0, 0, 15.0));
        
        // Next line
        [self applyClassicalFontToLayer:_lyricsTextLayers[2] size:18.0 bold:NO italic:YES];
        _lyricsTextLayers[2].opacity = 0.45;
        _lyricsTextLayers[2].alignmentMode = kCAAlignmentLeft;
        _lyricsTextLayers[2].frame = CGRectMake(innerLeft, cy - 65.0, innerW, 28.0);
        _lyricsTextLayers[2].foregroundColor = [NSColor colorWithWhite:0.80 alpha:0.75].CGColor;
        _lyricsTextLayers[2].string = lm.nextLine ?: @"";
        _lyricsTextLayers[2].transform = tPlaque;
    }
    // =========================================================================
    // STYLE 3: 🎼 Tilted 3D Chamber Manuscript (Orchestral Score & Vibrating Golden Acoustic Strings)
    // =========================================================================
    else {
        // Floating Conductor's Score Angled in 3D Space
        CATransform3D tScore = CATransform3DConcat(
            CATransform3DMakeRotation(16.0 * M_PI / 180.0, 1.0, 0.0, 0.0),
            CATransform3DMakeRotation(-6.0 * M_PI / 180.0, 0.0, 1.0, 0.0)
        );
        
        CGFloat cardW = W * 0.75;
        CGFloat cardH = 220.0;
        _lyricsPlaqueCard.opacity = 0.90;
        _lyricsPlaqueCard.frame = CGRectMake((W - cardW) * 0.5, cy - cardH * 0.5 + 20.0, cardW, cardH);
        _lyricsPlaqueCard.transform = tScore;
        
        // Active Lyric Embraced in Classical Quotation Marks
        NSString *classicalQuoted = [NSString stringWithFormat:@"“ %@ ”", curr];
        [self applyClassicalFontToLayer:_lyricsTextLayers[1] size:32.0 bold:YES italic:YES];
        _lyricsTextLayers[1].opacity = 1.0;
        _lyricsTextLayers[1].frame = CGRectMake((W - cardW * 0.9) * 0.5, cy + 20.0, cardW * 0.9, 50.0);
        _lyricsTextLayers[1].foregroundColor = ivoryCol.CGColor;
        _lyricsTextLayers[1].string = classicalQuoted;
        _lyricsTextLayers[1].shadowColor = goldCol.CGColor;
        _lyricsTextLayers[1].shadowOpacity = 0.90;
        _lyricsTextLayers[1].shadowRadius = 20.0;
        _lyricsTextLayers[1].transform = CATransform3DConcat(tScore, CATransform3DMakeTranslation(0, 0, 20.0));
        
        // 5 Vibrating Golden Acoustic Strings (Classical Violin / Harp Soundboard)
        _waveformLayer.opacity = 0.85;
        _waveformLayer.strokeColor = goldCol.CGColor;
        _waveformLayer.lineWidth = 1.3;
        _waveformLayer.transform = tScore;
        
        CGMutablePathRef stringsPath = CGPathCreateMutable();
        CGFloat stringBaseY = cy - 40.0;
        CGFloat stringW = cardW * 0.82;
        CGFloat startX = (W - stringW) * 0.5;
        int pts = 64;
        CGFloat stepX = stringW / (CGFloat)pts;
        
        for (int sIndex = 0; sIndex < 5; sIndex++) {
            CGFloat y0 = stringBaseY - sIndex * 8.0;
            CGFloat harmonicFreq = 1.0 + (CGFloat)sIndex * 0.5;
            CGFloat amp = (ae.currentBassLevel * 14.0 + ae.currentMidLevel * 8.0) * (1.0 - (CGFloat)sIndex * 0.15);
            
            CGPathMoveToPoint(stringsPath, NULL, startX, y0);
            for (int p = 0; p <= pts; p++) {
                CGFloat x = startX + p * stepX;
                CGFloat prog = (CGFloat)p / (CGFloat)pts;
                CGFloat vibration = sin(prog * M_PI * harmonicFreq * 2.0 + _phase * 6.0) * sin(prog * M_PI) * amp;
                CGPathAddLineToPoint(stringsPath, NULL, x, y0 + vibration);
            }
        }
        _waveformLayer.path = stringsPath;
        CGPathRelease(stringsPath);
    }
    
    // Bottom Golden Classical Progress Bar
    _progressBarLayer.opacity = 0.80;
    _progressBarLayer.strokeColor = goldCol.CGColor;
    _progressBarLayer.lineWidth = 2.0;
    CGMutablePathRef pPath = CGPathCreateMutable();
    CGFloat pbW = W * 0.45;
    CGFloat pbStartX = (W - pbW) * 0.5;
    CGFloat pbY = 75.0;
    
    // Background rail (dim)
    CGPathMoveToPoint(pPath, NULL, pbStartX, pbY);
    CGPathAddLineToPoint(pPath, NULL, pbStartX + pbW, pbY);
    
    // Active progress
    CGFloat curProg = lm.progress;
    CGFloat activeX = pbStartX + pbW * curProg;
    CGPathMoveToPoint(pPath, NULL, pbStartX, pbY);
    CGPathAddLineToPoint(pPath, NULL, activeX, pbY);
    
    // Diamond playhead marker
    CGPathMoveToPoint(pPath, NULL, activeX, pbY + 5.0);
    CGPathAddLineToPoint(pPath, NULL, activeX + 5.0, pbY);
    CGPathAddLineToPoint(pPath, NULL, activeX, pbY - 5.0);
    CGPathAddLineToPoint(pPath, NULL, activeX - 5.0, pbY);
    CGPathCloseSubpath(pPath);
    
    _progressBarLayer.path = pPath;
    CGPathRelease(pPath);
    
    // Track Info in Classical Small-Caps / Gold
    _infoTextLayer.opacity = 0.95;
    _infoTextLayer.frame = CGRectMake((W - maxW) * 0.5, 45.0, maxW, 20.0);
    [self applyClassicalFontToLayer:_infoTextLayer size:12.5 bold:YES italic:NO];
    _infoTextLayer.foregroundColor = [goldCol colorWithAlphaComponent:0.90].CGColor;
    _infoTextLayer.string = s.currentTrackInfo.length > 0 ? [NSString stringWithFormat:@"✦  %@  ✦", [s.currentTrackInfo uppercaseString]] : @"✦  DECKSI ACOUSTIC  ✦";
    
    // Hint Text Layer
    _hintTextLayer.opacity = 0.55;
    _hintTextLayer.frame = CGRectMake((W - maxW) * 0.5, 20.0, maxW, 18.0);
    [self applyClassicalFontToLayer:_hintTextLayer size:10.5 bold:NO italic:YES];
    _hintTextLayer.foregroundColor = [NSColor colorWithWhite:0.65 alpha:0.75].CGColor;
    _hintTextLayer.string = @"ESC to exit  •  TAB to cycle Classical 3D View Angles";
}

#pragma mark - Color Calculation

- (NSColor *)colorAtNormalizedPosition:(CGFloat)pos {
    pos = fmod(pos, 1.0);
    if (pos < 0.0) pos += 1.0;
    
    Settings *s = [Settings sharedSettings];
    switch (s.preset) {
        case LightingPresetPrismRainbow:
            return [NSColor colorWithHue:pos saturation:1.0 brightness:1.0 alpha:1.0];
        case LightingPresetCyberpunkNeon: {
            CGFloat wave = sin(pos * M_PI * 2.0) * 0.5 + 0.5;
            return [NSColor colorWithRed:(1.0 - wave) * 0.0 + wave * 1.0
                                   green:(1.0 - wave) * 0.94 + wave * 0.0
                                    blue:(1.0 - wave) * 1.0 + wave * 0.5 alpha:1.0];
        }
        case LightingPresetSunsetEmber: {
            CGFloat wave = sin(pos * M_PI * 2.0) * 0.5 + 0.5;
            return [NSColor colorWithRed:1.0 green:wave * 0.65 blue:(1.0 - wave) * 0.40 alpha:1.0];
        }
        case LightingPresetAuroraBorealis: {
            CGFloat wave = sin(pos * M_PI * 2.0) * 0.5 + 0.5;
            return [NSColor colorWithRed:(1.0 - wave) * 0.05 + wave * 0.65
                                   green:(1.0 - wave) * 0.95 + wave * 0.15
                                    blue:(1.0 - wave) * 0.75 + wave * 0.95 alpha:1.0];
        }
        case LightingPresetSolarPlasma: {
            CGFloat wave = sin(pos * M_PI * 2.0) * 0.5 + 0.5;
            return [NSColor colorWithRed:1.0 green:(1.0 - wave) * 0.85 + wave * 0.15 blue:0.05 alpha:1.0];
        }
        case LightingPresetToxicMatrix: {
            CGFloat wave = sin(pos * M_PI * 2.0) * 0.5 + 0.5;
            return [NSColor colorWithRed:(1.0 - wave) * 0.15 + wave * 0.02
                                   green:(1.0 - wave) * 1.0 + wave * 0.80
                                    blue:(1.0 - wave) * 0.20 + wave * 0.10 alpha:1.0];
        }
        case LightingPresetSynthwave: {
            CGFloat wave = sin(pos * M_PI * 2.0) * 0.5 + 0.5;
            return [NSColor colorWithRed:(1.0 - wave) * 0.54 + wave * 1.0
                                   green:(1.0 - wave) * 0.17 + wave * 0.50
                                    blue:(1.0 - wave) * 0.89 + wave * 0.31 alpha:1.0];
        }
        case LightingPresetMusicSync: {
            NSArray<NSColor *> *colors = s.trackColors;
            if (!colors || colors.count < 2) return [NSColor cyanColor];
            CGFloat scaled = pos * colors.count;
            NSInteger idx1 = (NSInteger)floor(scaled) % colors.count;
            NSInteger idx2 = (idx1 + 1) % colors.count;
            CGFloat frac = scaled - floor(scaled);
            NSColor *c1 = [colors[idx1] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            NSColor *c2 = [colors[idx2] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
            if (!c1 || !c2) return colors[0];
            return [NSColor colorWithRed:(1.0 - frac) * c1.redComponent + frac * c2.redComponent
                                   green:(1.0 - frac) * c1.greenComponent + frac * c2.greenComponent
                                    blue:(1.0 - frac) * c1.blueComponent + frac * c2.blueComponent alpha:1.0];
        }
        case LightingPresetPureHalo:
            return [NSColor colorWithRed:0.96 green:0.98 blue:1.0 alpha:1.0];
    }
}

#pragma mark - Mouse Down in Blackout Mode Exits

- (void)mouseDown:(NSEvent *)event {
    if ([Settings sharedSettings].blackoutMode) {
        [Settings sharedSettings].blackoutMode = NO;
        [[Settings sharedSettings] saveSettings];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DecksiBlackoutModeDidChange" object:nil];
    }
}

@end
