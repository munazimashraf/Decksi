#import "VideoAmbilightEngine.h"
#import "Settings.h"

#define NUM_TOP_ZONES 8
#define NUM_BOTTOM_ZONES 8
#define NUM_SIDE_ZONES 6

typedef struct {
    CGFloat r, g, b;
} AmbiRGBColor;

@interface VideoAmbilightEngine () {
    AmbiRGBColor _targetTop[NUM_TOP_ZONES];
    AmbiRGBColor _activeTop[NUM_TOP_ZONES];
    
    AmbiRGBColor _targetBottom[NUM_BOTTOM_ZONES];
    AmbiRGBColor _activeBottom[NUM_BOTTOM_ZONES];
    
    AmbiRGBColor _targetLeft[NUM_SIDE_ZONES];
    AmbiRGBColor _activeLeft[NUM_SIDE_ZONES];
    
    AmbiRGBColor _targetRight[NUM_SIDE_ZONES];
    AmbiRGBColor _activeRight[NUM_SIDE_ZONES];
    
    AmbiRGBColor _targetDominant;
    AmbiRGBColor _activeDominant;
    
    CGFloat _simPhase;
    NSTimeInterval _lastFrameTime;
}

@property (nonatomic, strong) NSArray<NSColor *> *topEdgeColors;
@property (nonatomic, strong) NSArray<NSColor *> *bottomEdgeColors;
@property (nonatomic, strong) NSArray<NSColor *> *leftEdgeColors;
@property (nonatomic, strong) NSArray<NSColor *> *rightEdgeColors;
@property (nonatomic, strong) NSColor *dominantColor;
@property (nonatomic, assign) CGFloat averageLuminance;
@property (nonatomic, assign) BOOL hasActiveVideo;

@end

@implementation VideoAmbilightEngine

+ (instancetype)sharedEngine {
    static VideoAmbilightEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VideoAmbilightEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _saturationBoost = 1.35;
        _smoothingFactor = 0.22;
        _averageLuminance = 0.5;
        _hasActiveVideo = NO;
        _simPhase = 0.0;
        _lastFrameTime = 0.0;
        
        // Initialize default cinematic teal & amber colors
        AmbiRGBColor defColor1 = {0.0, 0.75, 1.0}; // Cyan
        AmbiRGBColor defColor2 = {1.0, 0.45, 0.1}; // Warm Amber
        
        for (int i = 0; i < NUM_TOP_ZONES; i++) {
            _activeTop[i] = _targetTop[i] = (i < NUM_TOP_ZONES / 2) ? defColor1 : defColor2;
        }
        for (int i = 0; i < NUM_BOTTOM_ZONES; i++) {
            _activeBottom[i] = _targetBottom[i] = (i < NUM_BOTTOM_ZONES / 2) ? defColor1 : defColor2;
        }
        for (int i = 0; i < NUM_SIDE_ZONES; i++) {
            _activeLeft[i] = _targetLeft[i] = defColor1;
            _activeRight[i] = _targetRight[i] = defColor2;
        }
        _activeDominant = _targetDominant = defColor1;
        
        [self rebuildNSColors];
    }
    return self;
}

static inline void BoostRGB(CGFloat *r, CGFloat *g, CGFloat *b, CGFloat satBoost) {
    CGFloat luma = 0.299 * (*r) + 0.587 * (*g) + 0.114 * (*b);
    
    // Saturation enhancement
    *r = luma + (*r - luma) * satBoost;
    *g = luma + (*g - luma) * satBoost;
    *b = luma + (*b - luma) * satBoost;
    
    // Gamma curve for rich luminous ambiance
    if (luma > 0.01) {
        *r = powf(fmax(0.0, fmin(1.0, *r)), 0.85);
        *g = powf(fmax(0.0, fmin(1.0, *g)), 0.85);
        *b = powf(fmax(0.0, fmin(1.0, *b)), 0.85);
    }
    *r = fmax(0.0, fmin(1.0, *r));
    *g = fmax(0.0, fmin(1.0, *g));
    *b = fmax(0.0, fmin(1.0, *b));
}

- (void)processVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) return;
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    if (!base || width < 16 || height < 16) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        return;
    }
    
    _lastFrameTime = [NSDate timeIntervalSinceReferenceDate];
    _hasActiveVideo = YES;
    CGFloat sat = [Settings sharedSettings].videoSaturationBoost ?: self.saturationBoost;
    
    // 1. Intelligent Letterbox & Pillarbox Detection (Skip black bars in movies)
    size_t effectiveTopY = 1;
    size_t maxScanY = height / 4;
    for (size_t y = 0; y < maxScanY; y++) {
        CGFloat rowLuma = 0.0;
        for (size_t x = width / 4; x < 3 * width / 4; x += 4) {
            uint8_t *px = base + (y * bytesPerRow) + (x * 4);
            rowLuma += (0.114 * px[0] + 0.587 * px[1] + 0.299 * px[2]) / 255.0;
        }
        rowLuma /= (width / 8);
        if (rowLuma > 0.035) {
            effectiveTopY = y;
            break;
        }
    }
    
    size_t effectiveBottomY = height - 2;
    for (size_t y = height - 1; y > height - maxScanY; y--) {
        CGFloat rowLuma = 0.0;
        for (size_t x = width / 4; x < 3 * width / 4; x += 4) {
            uint8_t *px = base + (y * bytesPerRow) + (x * 4);
            rowLuma += (0.114 * px[0] + 0.587 * px[1] + 0.299 * px[2]) / 255.0;
        }
        rowLuma /= (width / 8);
        if (rowLuma > 0.035) {
            effectiveBottomY = y;
            break;
        }
    }
    
    // 2. Sample Top Edge (8 Zones)
    size_t zoneW = width / NUM_TOP_ZONES;
    for (int z = 0; z < NUM_TOP_ZONES; z++) {
        size_t startX = z * zoneW;
        CGFloat sumR = 0, sumG = 0, sumB = 0;
        int count = 0;
        for (size_t dy = 0; dy < 3 && (effectiveTopY + dy) < height; dy++) {
            for (size_t dx = 0; dx < zoneW; dx += 2) {
                uint8_t *px = base + ((effectiveTopY + dy) * bytesPerRow) + ((startX + dx) * 4);
                sumB += px[0] / 255.0;
                sumG += px[1] / 255.0;
                sumR += px[2] / 255.0;
                count++;
            }
        }
        if (count > 0) {
            CGFloat r = sumR / count, g = sumG / count, b = sumB / count;
            BoostRGB(&r, &g, &b, sat);
            _targetTop[z] = (AmbiRGBColor){r, g, b};
        }
    }
    
    // 3. Sample Bottom Edge (8 Zones)
    for (int z = 0; z < NUM_BOTTOM_ZONES; z++) {
        size_t startX = z * zoneW;
        CGFloat sumR = 0, sumG = 0, sumB = 0;
        int count = 0;
        for (size_t dy = 0; dy < 3 && (effectiveBottomY >= dy); dy++) {
            for (size_t dx = 0; dx < zoneW; dx += 2) {
                uint8_t *px = base + ((effectiveBottomY - dy) * bytesPerRow) + ((startX + dx) * 4);
                sumB += px[0] / 255.0;
                sumG += px[1] / 255.0;
                sumR += px[2] / 255.0;
                count++;
            }
        }
        if (count > 0) {
            CGFloat r = sumR / count, g = sumG / count, b = sumB / count;
            BoostRGB(&r, &g, &b, sat);
            _targetBottom[z] = (AmbiRGBColor){r, g, b};
        }
    }
    
    // 4. Sample Left Edge (6 Zones)
    size_t zoneH = height / NUM_SIDE_ZONES;
    for (int z = 0; z < NUM_SIDE_ZONES; z++) {
        size_t startY = z * zoneH;
        CGFloat sumR = 0, sumG = 0, sumB = 0;
        int count = 0;
        for (size_t dy = 0; dy < zoneH; dy += 2) {
            for (size_t dx = 0; dx < 3 && dx < width; dx++) {
                uint8_t *px = base + ((startY + dy) * bytesPerRow) + (dx * 4);
                sumB += px[0] / 255.0;
                sumG += px[1] / 255.0;
                sumR += px[2] / 255.0;
                count++;
            }
        }
        if (count > 0) {
            CGFloat r = sumR / count, g = sumG / count, b = sumB / count;
            BoostRGB(&r, &g, &b, sat);
            _targetLeft[z] = (AmbiRGBColor){r, g, b};
        }
    }
    
    // 5. Sample Right Edge (6 Zones)
    for (int z = 0; z < NUM_SIDE_ZONES; z++) {
        size_t startY = z * zoneH;
        CGFloat sumR = 0, sumG = 0, sumB = 0;
        int count = 0;
        for (size_t dy = 0; dy < zoneH; dy += 2) {
            for (size_t dx = 0; dx < 3 && (width - 1 - dx) < width; dx++) {
                uint8_t *px = base + ((startY + dy) * bytesPerRow) + ((width - 1 - dx) * 4);
                sumB += px[0] / 255.0;
                sumG += px[1] / 255.0;
                sumR += px[2] / 255.0;
                count++;
            }
        }
        if (count > 0) {
            CGFloat r = sumR / count, g = sumG / count, b = sumB / count;
            BoostRGB(&r, &g, &b, sat);
            _targetRight[z] = (AmbiRGBColor){r, g, b};
        }
    }
    
    // 6. Overall Dominant Color & Luma
    CGFloat totalLuma = 0.0;
    CGFloat domR = 0, domG = 0, domB = 0;
    for (int i = 0; i < NUM_TOP_ZONES; i++) {
        domR += _targetTop[i].r; domG += _targetTop[i].g; domB += _targetTop[i].b;
    }
    for (int i = 0; i < NUM_BOTTOM_ZONES; i++) {
        domR += _targetBottom[i].r; domG += _targetBottom[i].g; domB += _targetBottom[i].b;
    }
    int totalSampled = NUM_TOP_ZONES + NUM_BOTTOM_ZONES;
    domR /= totalSampled; domG /= totalSampled; domB /= totalSampled;
    totalLuma = 0.299 * domR + 0.587 * domG + 0.114 * domB;
    
    _targetDominant = (AmbiRGBColor){domR, domG, domB};
    _averageLuminance = totalLuma;
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

// 60 FPS LERP Smoothing & Fallback Generator
- (void)tick {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    BOOL isStreamLive = (now - _lastFrameTime < 1.0);
    
    if (!isStreamLive) {
        // Fallback Simulation: Shifting Cinematic Atmospheric Lighting
        _simPhase += 0.015;
        for (int i = 0; i < NUM_TOP_ZONES; i++) {
            CGFloat p = _simPhase + (CGFloat)i * 0.08;
            _targetTop[i] = (AmbiRGBColor){
                0.5 + 0.5 * sin(p),
                0.4 + 0.4 * cos(p * 1.3),
                0.6 + 0.4 * sin(p * 0.7 + 2.0)
            };
        }
        for (int i = 0; i < NUM_BOTTOM_ZONES; i++) {
            CGFloat p = _simPhase + (CGFloat)i * 0.08 + 1.5;
            _targetBottom[i] = (AmbiRGBColor){
                0.5 + 0.5 * sin(p),
                0.4 + 0.4 * cos(p * 1.3),
                0.6 + 0.4 * sin(p * 0.7 + 2.0)
            };
        }
        for (int i = 0; i < NUM_SIDE_ZONES; i++) {
            _targetLeft[i] = _targetTop[i % NUM_TOP_ZONES];
            _targetRight[i] = _targetBottom[i % NUM_BOTTOM_ZONES];
        }
    }
    
    // Smooth Exponential Moving Average (LERP)
    CGFloat k = self.smoothingFactor;
    for (int i = 0; i < NUM_TOP_ZONES; i++) {
        _activeTop[i].r += (_targetTop[i].r - _activeTop[i].r) * k;
        _activeTop[i].g += (_targetTop[i].g - _activeTop[i].g) * k;
        _activeTop[i].b += (_targetTop[i].b - _activeTop[i].b) * k;
    }
    for (int i = 0; i < NUM_BOTTOM_ZONES; i++) {
        _activeBottom[i].r += (_targetBottom[i].r - _activeBottom[i].r) * k;
        _activeBottom[i].g += (_targetBottom[i].g - _activeBottom[i].g) * k;
        _activeBottom[i].b += (_targetBottom[i].b - _activeBottom[i].b) * k;
    }
    for (int i = 0; i < NUM_SIDE_ZONES; i++) {
        _activeLeft[i].r += (_targetLeft[i].r - _activeLeft[i].r) * k;
        _activeLeft[i].g += (_targetLeft[i].g - _activeLeft[i].g) * k;
        _activeLeft[i].b += (_targetLeft[i].b - _activeLeft[i].b) * k;
        
        _activeRight[i].r += (_targetRight[i].r - _activeRight[i].r) * k;
        _activeRight[i].g += (_targetRight[i].g - _activeRight[i].g) * k;
        _activeRight[i].b += (_targetRight[i].b - _activeRight[i].b) * k;
    }
    
    _activeDominant.r += (_targetDominant.r - _activeDominant.r) * k;
    _activeDominant.g += (_targetDominant.g - _activeDominant.g) * k;
    _activeDominant.b += (_targetDominant.b - _activeDominant.b) * k;
    
    [self rebuildNSColors];
}

- (void)rebuildNSColors {
    NSMutableArray *top = [NSMutableArray arrayWithCapacity:NUM_TOP_ZONES];
    for (int i = 0; i < NUM_TOP_ZONES; i++) {
        [top addObject:[NSColor colorWithRed:_activeTop[i].r green:_activeTop[i].g blue:_activeTop[i].b alpha:1.0]];
    }
    self.topEdgeColors = top;
    
    NSMutableArray *bot = [NSMutableArray arrayWithCapacity:NUM_BOTTOM_ZONES];
    for (int i = 0; i < NUM_BOTTOM_ZONES; i++) {
        [bot addObject:[NSColor colorWithRed:_activeBottom[i].r green:_activeBottom[i].g blue:_activeBottom[i].b alpha:1.0]];
    }
    self.bottomEdgeColors = bot;
    
    NSMutableArray *left = [NSMutableArray arrayWithCapacity:NUM_SIDE_ZONES];
    for (int i = 0; i < NUM_SIDE_ZONES; i++) {
        [left addObject:[NSColor colorWithRed:_activeLeft[i].r green:_activeLeft[i].g blue:_activeLeft[i].b alpha:1.0]];
    }
    self.leftEdgeColors = left;
    
    NSMutableArray *right = [NSMutableArray arrayWithCapacity:NUM_SIDE_ZONES];
    for (int i = 0; i < NUM_SIDE_ZONES; i++) {
        [right addObject:[NSColor colorWithRed:_activeRight[i].r green:_activeRight[i].g blue:_activeRight[i].b alpha:1.0]];
    }
    self.rightEdgeColors = right;
    
    self.dominantColor = [NSColor colorWithRed:_activeDominant.r green:_activeDominant.g blue:_activeDominant.b alpha:1.0];
}

@end
