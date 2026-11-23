#import <Cocoa/Cocoa.h>

@interface GlowParticle : NSObject
@property (nonatomic, assign) CGPoint position;
@property (nonatomic, assign) CGPoint velocity;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) CGFloat maxAlpha;
@property (nonatomic, assign) CGFloat size;
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, assign) CGFloat life;       // 1.0 down to 0.0
@property (nonatomic, assign) CGFloat decayRate;
@property (nonatomic, assign) NSInteger edge;     // 0=bottom, 1=right, 2=top, 3=left
@end

@interface ParticleEngine : NSObject

@property (nonatomic, strong) NSMutableArray<GlowParticle *> *particles;
@property (nonatomic, assign) NSInteger maxParticles;
@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedEngine;

- (void)updateParticlesInBounds:(NSRect)bounds
                      bassLevel:(CGFloat)bass
                       midLevel:(CGFloat)mid
                      highLevel:(CGFloat)high
                      beatPulse:(CGFloat)beat
                    colorHelper:(NSColor * (^)(CGFloat progress))colorHelper;

- (void)drawParticlesInContext:(CGContextRef)ctx bounds:(NSRect)bounds;

@end
