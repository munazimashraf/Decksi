#import "ParticleEngine.h"

@implementation GlowParticle
@end

@implementation ParticleEngine

+ (instancetype)sharedEngine {
    static ParticleEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ParticleEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _particles = [NSMutableArray arrayWithCapacity:60];
        _maxParticles = 50;
        _enabled = YES;
    }
    return self;
}

- (void)updateParticlesInBounds:(NSRect)bounds
                      bassLevel:(CGFloat)bass
                       midLevel:(CGFloat)mid
                      highLevel:(CGFloat)high
                      beatPulse:(CGFloat)beat
                    colorHelper:(NSColor * (^)(CGFloat progress))colorHelper {
    if (!self.enabled) return;
    
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;
    if (W <= 0 || H <= 0) return;
    
    // 1. Update existing particles
    NSMutableArray *expired = [NSMutableArray array];
    for (GlowParticle *p in self.particles) {
        p.position = CGPointMake(p.position.x + p.velocity.x * (1.0 + mid * 1.5),
                                 p.position.y + p.velocity.y * (1.0 + mid * 1.5));
                                 
        // Treble sparkle makes particles flash brighter
        CGFloat sparkle = high * 0.45;
        p.alpha = (p.life * p.maxAlpha) + sparkle;
        if (p.alpha > 1.0) p.alpha = 1.0;
        
        p.life -= p.decayRate;
        if (p.life <= 0.0) {
            [expired addObject:p];
        }
    }
    [self.particles removeObjectsInArray:expired];
    
    // 2. Spawn new particles
    // Spawn rate increases with beat and bass
    NSInteger spawnCount = 1;
    if (beat > 0.4) spawnCount += (NSInteger)(beat * 4);
    if (self.particles.count + spawnCount > self.maxParticles) {
        spawnCount = self.maxParticles - self.particles.count;
    }
    
    for (int i = 0; i < spawnCount; i++) {
        GlowParticle *p = [[GlowParticle alloc] init];
        p.edge = arc4random_uniform(4);
        CGFloat edgePos = (CGFloat)arc4random_uniform(1000) / 1000.0;
        CGFloat speed = 0.8 + ((CGFloat)arc4random_uniform(100) / 100.0) * 1.8 + (bass * 2.5);
        
        if (p.edge == 0) { // Bottom edge -> moving up
            p.position = CGPointMake(edgePos * W, 2.0);
            p.velocity = CGPointMake(((CGFloat)arc4random_uniform(100) / 100.0 - 0.5) * 0.8, speed);
        } else if (p.edge == 1) { // Right edge -> moving left
            p.position = CGPointMake(W - 2.0, edgePos * H);
            p.velocity = CGPointMake(-speed, ((CGFloat)arc4random_uniform(100) / 100.0 - 0.5) * 0.8);
        } else if (p.edge == 2) { // Top edge -> moving down
            p.position = CGPointMake(edgePos * W, H - 2.0);
            p.velocity = CGPointMake(((CGFloat)arc4random_uniform(100) / 100.0 - 0.5) * 0.8, -speed);
        } else { // Left edge -> moving right
            p.position = CGPointMake(2.0, edgePos * H);
            p.velocity = CGPointMake(speed, ((CGFloat)arc4random_uniform(100) / 100.0 - 0.5) * 0.8);
        }
        
        p.size = 2.5 + ((CGFloat)arc4random_uniform(100) / 100.0) * 4.5 + (high * 3.0);
        p.maxAlpha = 0.5 + ((CGFloat)arc4random_uniform(100) / 100.0) * 0.5;
        p.alpha = p.maxAlpha;
        p.life = 1.0;
        p.decayRate = 0.012 + ((CGFloat)arc4random_uniform(100) / 100.0) * 0.015;
        
        if (colorHelper) {
            p.color = colorHelper(edgePos);
        } else {
            p.color = [NSColor cyanColor];
        }
        
        [self.particles addObject:p];
    }
}

- (void)drawParticlesInContext:(CGContextRef)ctx bounds:(NSRect)bounds {
    if (!self.enabled || self.particles.count == 0) return;
    
    CGContextSaveGState(ctx);
    // Additive screen blending for luminous starry glow
    CGContextSetBlendMode(ctx, kCGBlendModePlusLighter);
    
    for (GlowParticle *p in self.particles) {
        if (p.alpha <= 0.01) continue;
        
        NSColor *col = [p.color colorWithAlphaComponent:p.alpha];
        CGColorRef cCore = [col CGColor];
        CGColorRef cFade = [[col colorWithAlphaComponent:0.0] CGColor];
        CFArrayRef colors = (__bridge CFArrayRef)@[(__bridge id)cCore, (__bridge id)cFade];
        CGGradientRef grad = CGGradientCreateWithColors(NULL, colors, NULL);
        
        CGPoint center = p.position;
        CGFloat radius = p.size * 2.2;
        
        CGContextDrawRadialGradient(ctx, grad, center, 0, center, radius, kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(grad);
    }
    
    CGContextRestoreGState(ctx);
}

@end
