#import <Cocoa/Cocoa.h>

@interface LyricLine : NSObject
@property (nonatomic, assign) NSTimeInterval time;
@property (nonatomic, copy) NSString *text;
@end

@interface LyricsManager : NSObject

@property (nonatomic, strong, readonly) NSArray<LyricLine *> *lines;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, strong, readonly) NSString *currentLine;
@property (nonatomic, strong, readonly) NSString *previousLine;
@property (nonatomic, strong, readonly) NSString *nextLine;
@property (nonatomic, assign, readonly) BOOL hasLyrics;
@property (nonatomic, assign) NSTimeInterval playbackPosition;
@property (nonatomic, assign) NSTimeInterval trackDuration;
@property (nonatomic, assign, readonly) CGFloat progress; // 0.0 - 1.0

+ (instancetype)sharedManager;

- (void)fetchLyricsForTrack:(NSString *)track artist:(NSString *)artist;
- (void)updatePlaybackPosition:(NSTimeInterval)position isPlaying:(BOOL)isPlaying;
- (void)tickTimeDelta:(NSTimeInterval)dt;
- (NSArray<LyricLine *> *)linesWindowWithCount:(NSInteger)count;
- (void)clearLyrics;

@end
