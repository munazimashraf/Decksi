#import "LyricsManager.h"

@implementation LyricLine
@end

@interface LyricsManager ()
@property (nonatomic, strong) NSMutableArray<LyricLine *> *lineStore;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) NSString *currentLine;
@property (nonatomic, strong) NSString *previousLine;
@property (nonatomic, strong) NSString *nextLine;
@property (nonatomic, assign) BOOL hasLyrics;
@property (nonatomic, strong) NSString *activeTrack;
@property (nonatomic, strong) NSString *activeArtist;
@property (nonatomic, assign) BOOL isPlaying;
@end

@implementation LyricsManager

- (NSArray<LyricLine *> *)lines {
    return self.lineStore;
}

+ (instancetype)sharedManager {
    static LyricsManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LyricsManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lineStore = [NSMutableArray array];
        _currentIndex = -1;
        _currentLine = @"";
        _previousLine = @"";
        _nextLine = @"";
        _hasLyrics = NO;
        _playbackPosition = 0.0;
        _trackDuration = 180.0;
        _isPlaying = NO;
    }
    return self;
}

- (CGFloat)progress {
    if (self.trackDuration <= 0.0) return 0.0;
    return fmin(1.0, fmax(0.0, self.playbackPosition / self.trackDuration));
}

- (void)clearLyrics {
    [self.lineStore removeAllObjects];
    self.currentIndex = -1;
    self.currentLine = @"";
    self.previousLine = @"";
    self.nextLine = @"";
    self.hasLyrics = NO;
    self.playbackPosition = 0.0;
}

- (void)fetchLyricsForTrack:(NSString *)track artist:(NSString *)artist {
    if (track.length == 0) return;
    
    if ([self.activeTrack isEqualToString:track] && [self.activeArtist isEqualToString:artist] && self.lines.count > 0) {
        return;
    }
    
    self.activeTrack = track;
    self.activeArtist = artist;
    [self clearLyrics];
    self.currentLine = [NSString stringWithFormat:@"%@ — %@", track, artist.length > 0 ? artist : @"Playing"];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *localLyrics = [self fetchAppleMusicLocalLyrics];
        if (localLyrics.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self parseLyricsText:localLyrics];
            });
            return;
        }
        [self fetchFromLRCLibTrack:track artist:artist];
    });
}

- (NSString *)fetchAppleMusicLocalLyrics {
    BOOL isRunning = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.Music"].count > 0;
    if (!isRunning) return nil;
    
    NSString *src = @"tell application \"Music\"\n"
                    @"  try\n"
                    @"    if player state is playing then\n"
                    @"      return (get lyrics of current track)\n"
                    @"    end if\n"
                    @"  end try\n"
                    @"end tell\n"
                    @"return \"\"";
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:src];
    NSDictionary *err = nil;
    NSAppleEventDescriptor *res = [script executeAndReturnError:&err];
    NSString *lyr = [res stringValue];
    return (lyr.length > 5) ? lyr : nil;
}

- (NSString *)cleanArtist:(NSString *)artist {
    if (artist.length == 0) return @"";
    NSArray *delims = @[@",", @"&", @"feat.", @"feat", @"ft.", @"ft", @"/"];
    NSString *p = artist;
    for (NSString *d in delims) {
        NSRange r = [p rangeOfString:d options:NSCaseInsensitiveSearch];
        if (r.location != NSNotFound) {
            p = [p substringToIndex:r.location];
        }
    }
    return [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)fetchFromLRCLibTrack:(NSString *)track artist:(NSString *)artist {
    NSString *cleanTrack = [self cleanTitle:track];
    NSString *primaryArtist = [self cleanArtist:artist];
    
    NSLog(@"[Decksi Lyrics] Searching lyrics for '%@' by '%@'...", cleanTrack, primaryArtist);
    
    // 1. Search API (Ultra-tolerant with multiple artists and movie soundtracks)
    NSString *query = (primaryArtist.length > 0) ? [NSString stringWithFormat:@"%@ %@", cleanTrack, primaryArtist] : cleanTrack;
    NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *searchUrlStr = [NSString stringWithFormat:@"https://lrclib.net/api/search?q=%@", encodedQuery];
    
    NSURL *url = [NSURL URLWithString:searchUrlStr];
    if (!url) return;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 4.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    [[session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error && data) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSArray class]] && [(NSArray *)json count] > 0) {
                NSArray *items = (NSArray *)json;
                NSDictionary *chosen = nil;
                for (NSDictionary *item in items) {
                    if ([item isKindOfClass:[NSDictionary class]] && [item[@"syncedLyrics"] length] > 0) {
                        chosen = item;
                        break;
                    }
                }
                if (!chosen) chosen = items.firstObject;
                
                NSString *syncedLyrics = chosen[@"syncedLyrics"];
                NSString *plainLyrics = chosen[@"plainLyrics"];
                
                if (syncedLyrics.length > 0 || plainLyrics.length > 0) {
                    NSLog(@"[Decksi Lyrics] Successfully matched '%@' (synced: %d)", chosen[@"trackName"], syncedLyrics.length > 0);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (syncedLyrics.length > 0) {
                            [self parseLRC:syncedLyrics];
                        } else {
                            [self parsePlainText:plainLyrics];
                        }
                    });
                    return;
                }
            }
        }
        
        // 2. Exact API fallback
        NSString *encodedTrack = [cleanTrack stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *encodedArtist = [primaryArtist stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *getUrlStr = [NSString stringWithFormat:@"https://lrclib.net/api/get?artist_name=%@&track_name=%@", encodedArtist, encodedTrack];
        NSURL *getUrl = [NSURL URLWithString:getUrlStr];
        if (getUrl) {
            [[session dataTaskWithURL:getUrl completionHandler:^(NSData * _Nullable gData, NSURLResponse * _Nullable gResp, NSError * _Nullable gErr) {
                if (!gErr && gData) {
                    NSDictionary *gJson = [NSJSONSerialization JSONObjectWithData:gData options:0 error:nil];
                    if ([gJson isKindOfClass:[NSDictionary class]]) {
                        NSString *synced = gJson[@"syncedLyrics"];
                        NSString *plain = gJson[@"plainLyrics"];
                        if (synced.length > 0 || plain.length > 0) {
                            NSLog(@"[Decksi Lyrics] Matched via exact API: '%@'", cleanTrack);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (synced.length > 0) [self parseLRC:synced];
                                else [self parsePlainText:plain];
                            });
                        }
                    }
                }
            }] resume];
        }
    }] resume];
}

- (NSString *)cleanTitle:(NSString *)title {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s*[\\[\\(].*?[\\]\\)]|\\s*-\\s*.*" options:0 error:nil];
    return [regex stringByReplacingMatchesInString:title options:0 range:NSMakeRange(0, title.length) withTemplate:@""];
}

- (void)parseLRC:(NSString *)lrc {
    [self.lineStore removeAllObjects];
    
    NSArray *rawLines = [lrc componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSRegularExpression *timeRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d{1,2}):(\\d{2})[\\.:](\\d{2,3})\\]\\s*(.*)$" options:0 error:nil];
    
    for (NSString *line in rawLines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0) continue;
        
        NSTextCheckingResult *match = [timeRegex firstMatchInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)];
        if (match && match.numberOfRanges >= 5) {
            NSString *minStr = [trimmed substringWithRange:[match rangeAtIndex:1]];
            NSString *secStr = [trimmed substringWithRange:[match rangeAtIndex:2]];
            NSString *msStr  = [trimmed substringWithRange:[match rangeAtIndex:3]];
            NSString *text   = [trimmed substringWithRange:[match rangeAtIndex:4]];
            
            NSTimeInterval sec = [minStr doubleValue] * 60.0 + [secStr doubleValue] + ([msStr doubleValue] / (msStr.length == 3 ? 1000.0 : 100.0));
            
            LyricLine *ll = [[LyricLine alloc] init];
            ll.time = sec;
            ll.text = text;
            [self.lineStore addObject:ll];
        }
    }
    
    [self.lineStore sortUsingComparator:^NSComparisonResult(LyricLine *a, LyricLine *b) {
        if (a.time < b.time) return NSOrderedAscending;
        if (a.time > b.time) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    
    self.hasLyrics = (self.lineStore.count > 0);
    [self updateLinesForCurrentPosition];
}

- (void)parsePlainText:(NSString *)text {
    [self.lineStore removeAllObjects];
    NSArray *rawLines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *valid = [NSMutableArray array];
    for (NSString *l in rawLines) {
        NSString *trim = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trim.length > 0) [valid addObject:trim];
    }
    if (valid.count == 0) return;
    
    NSTimeInterval pace = (self.trackDuration > 30.0 ? self.trackDuration : 180.0) / (NSTimeInterval)valid.count;
    for (NSUInteger i = 0; i < valid.count; i++) {
        LyricLine *ll = [[LyricLine alloc] init];
        ll.time = (NSTimeInterval)i * pace;
        ll.text = valid[i];
        [self.lineStore addObject:ll];
    }
    self.hasLyrics = (self.lineStore.count > 0);
    [self updateLinesForCurrentPosition];
}

- (void)parseLyricsText:(NSString *)text {
    if ([text containsString:@"[00:"]) {
        [self parseLRC:text];
    } else {
        [self parsePlainText:text];
    }
}

- (void)updatePlaybackPosition:(NSTimeInterval)position isPlaying:(BOOL)isPlaying {
    self.playbackPosition = position;
    self.isPlaying = isPlaying;
    [self updateLinesForCurrentPosition];
}

- (void)tickTimeDelta:(NSTimeInterval)dt {
    if (self.isPlaying) {
        self.playbackPosition += dt;
        [self updateLinesForCurrentPosition];
    }
}

- (void)updateLinesForCurrentPosition {
    if (!self.hasLyrics || self.lines.count == 0) {
        return;
    }
    
    NSInteger currentIdx = -1;
    for (NSInteger i = (NSInteger)self.lines.count - 1; i >= 0; i--) {
        if (self.playbackPosition >= self.lines[i].time) {
            currentIdx = i;
            break;
        }
    }
    
    self.currentIndex = currentIdx;
    if (currentIdx >= 0) {
        self.currentLine = self.lines[currentIdx].text;
        self.previousLine = (currentIdx > 0) ? self.lines[currentIdx - 1].text : @"";
        self.nextLine = (currentIdx + 1 < (NSInteger)self.lines.count) ? self.lines[currentIdx + 1].text : @"";
    } else if (self.lines.count > 0) {
        self.currentLine = self.lines[0].text;
        self.previousLine = @"";
        self.nextLine = (self.lines.count > 1) ? self.lines[1].text : @"";
    }
}

- (NSArray<LyricLine *> *)linesWindowWithCount:(NSInteger)count {
    if (!self.hasLyrics || self.lines.count == 0) return @[];
    NSInteger half = count / 2;
    NSInteger start = fmax(0, self.currentIndex - half);
    NSInteger end = fmin(self.lines.count, start + count);
    if (end - start < count && start > 0) {
        start = fmax(0, end - count);
    }
    return [self.lines subarrayWithRange:NSMakeRange(start, end - start)];
}

@end
