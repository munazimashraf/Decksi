#import <Cocoa/Cocoa.h>

@protocol MusicDetectorDelegate <NSObject>
@optional
- (void)musicDetectorTrackDidChange:(NSString *)track artist:(NSString *)artist album:(NSString *)album colors:(NSArray<NSColor *> *)colors;
- (void)musicDetectorPlaybackStateDidChange:(BOOL)isPlaying;
@end

@interface MusicDetector : NSObject

@property (nonatomic, weak) id<MusicDetectorDelegate> delegate;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) NSString *currentTrack;
@property (nonatomic, readonly) NSString *currentArtist;
@property (nonatomic, readonly) NSString *currentAlbum;
@property (nonatomic, readonly) NSArray<NSColor *> *currentColors;

+ (instancetype)sharedDetector;
- (void)startMonitoring;
- (void)stopMonitoring;
- (void)checkCurrentPlayerState;

@end
