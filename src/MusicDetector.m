#import "MusicDetector.h"
#import "Settings.h"
#import "LyricsManager.h"

@interface MusicDetector ()
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) NSString *currentTrack;
@property (nonatomic, strong) NSString *currentArtist;
@property (nonatomic, strong) NSString *currentAlbum;
@property (nonatomic, strong) NSArray<NSColor *> *currentColors;
@property (nonatomic, strong) NSTimer *pollTimer;
@end

@implementation MusicDetector

+ (instancetype)sharedDetector {
    static MusicDetector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MusicDetector alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isPlaying = NO;
        _currentTrack = @"";
        _currentArtist = @"";
        _currentAlbum = @"";
        _currentColors = @[
            [NSColor colorWithRed:0.1 green:0.8 blue:1.0 alpha:1.0],
            [NSColor colorWithRed:1.0 green:0.2 blue:0.7 alpha:1.0]
        ];
    }
    return self;
}

- (void)startMonitoring {
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    
    // Apple Music notifications
    [dnc addObserver:self
            selector:@selector(handleAppleMusicNotification:)
                name:@"com.apple.Music.playerInfo"
              object:nil];
              
    // Spotify notifications
    [dnc addObserver:self
            selector:@selector(handleSpotifyNotification:)
                name:@"com.spotify.client.PlaybackStateChanged"
              object:nil];
              
    // High-precision periodic polling (every 1 second) to keep playback position & state perfectly in sync
    __weak typeof(self) weakSelf = self;
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf checkCurrentPlayerState];
    }];
    
    [self checkCurrentPlayerState];
}

- (void)stopMonitoring {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [self.pollTimer invalidate];
    self.pollTimer = nil;
}

#pragma mark - Notifications

- (void)handleAppleMusicNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    
    NSString *playerState = userInfo[@"Player State"];
    BOOL playing = [playerState isEqualToString:@"Playing"];
    NSString *name = userInfo[@"Name"] ?: @"";
    NSString *artist = userInfo[@"Artist"] ?: @"";
    NSString *album = userInfo[@"Album"] ?: @"";
    NSString *genre = userInfo[@"Genre"] ?: @"";
    
    NSNumber *totalTimeMs = userInfo[@"Total Time"];
    NSTimeInterval duration = totalTimeMs ? [totalTimeMs doubleValue] / 1000.0 : 180.0;
    
    [self updateTrack:name artist:artist album:album genre:genre isPlaying:playing duration:duration];
}

- (void)handleSpotifyNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) return;
    
    NSString *playerState = userInfo[@"Player State"];
    BOOL playing = [playerState isEqualToString:@"Playing"];
    NSString *name = userInfo[@"Name"] ?: @"";
    NSString *artist = userInfo[@"Artist"] ?: @"";
    NSString *album = userInfo[@"Album"] ?: @"";
    
    NSNumber *durationMs = userInfo[@"Duration"];
    NSTimeInterval duration = durationMs ? [durationMs doubleValue] / 1000.0 : 180.0;
    
    NSNumber *playbackPos = userInfo[@"Playback Position"];
    if (playbackPos) {
        [[LyricsManager sharedManager] updatePlaybackPosition:[playbackPos doubleValue] isPlaying:playing];
    }
    
    [self updateTrack:name artist:artist album:album genre:@"" isPlaying:playing duration:duration];
}

- (void)updateTrack:(NSString *)track artist:(NSString *)artist album:(NSString *)album genre:(NSString *)genre isPlaying:(BOOL)playing duration:(NSTimeInterval)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isPlaying = playing;
        [Settings sharedSettings].isMusicPlaying = playing;
        [Settings sharedSettings].currentTrackDuration = duration;
        [LyricsManager sharedManager].trackDuration = duration;
        
        if (track.length > 0) {
            self.currentTrack = track;
            self.currentArtist = artist;
            self.currentAlbum = album;
            
            NSString *infoStr = artist.length > 0 ? [NSString stringWithFormat:@"%@ — %@", track, artist] : track;
            [Settings sharedSettings].currentTrackInfo = infoStr;
            
            // Harmonic mood colors
            self.currentColors = [self generateHarmonicColorsForTrack:track artist:artist album:album genre:genre];
            [Settings sharedSettings].trackColors = self.currentColors;
            
            // Fetch synced lyrics immediately
            [[LyricsManager sharedManager] fetchLyricsForTrack:track artist:artist];
            
            if ([self.delegate respondsToSelector:@selector(musicDetectorTrackDidChange:artist:album:colors:)]) {
                [self.delegate musicDetectorTrackDidChange:track artist:artist album:album colors:self.currentColors];
            }
        }
        
        if ([self.delegate respondsToSelector:@selector(musicDetectorPlaybackStateDidChange:)]) {
            [self.delegate musicDetectorPlaybackStateDidChange:playing];
        }
    });
}

#pragma mark - Color Palette Generator

- (NSArray<NSColor *> *)generateHarmonicColorsForTrack:(NSString *)track
                                               artist:(NSString *)artist
                                                album:(NSString *)album
                                                genre:(NSString *)genre {
    NSString *combined = [NSString stringWithFormat:@"%@-%@-%@-%@", genre, track, artist, album];
    NSUInteger hash = 5381;
    for (NSUInteger i = 0; i < combined.length; i++) {
        hash = ((hash << 5) + hash) + [combined characterAtIndex:i];
    }
    
    CGFloat primaryHue = fmod((CGFloat)(hash % 360) / 360.0, 1.0);
    CGFloat offset = 0.33 + fmod((CGFloat)((hash / 360) % 50) / 100.0, 0.34);
    CGFloat secondaryHue = fmod(primaryHue + offset, 1.0);
    CGFloat tertiaryHue = fmod(primaryHue + 2.0 * offset, 1.0);
    
    NSColor *c1 = [NSColor colorWithHue:primaryHue saturation:0.95 brightness:1.0 alpha:1.0];
    NSColor *c2 = [NSColor colorWithHue:secondaryHue saturation:0.90 brightness:1.0 alpha:1.0];
    NSColor *c3 = [NSColor colorWithHue:tertiaryHue saturation:0.85 brightness:1.0 alpha:1.0];
    
    return @[c1, c2, c3];
}

#pragma mark - Active Polling & Playback Position Query

- (void)checkCurrentPlayerState {
    BOOL musicRunning = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.Music"].count > 0;
    BOOL spotifyRunning = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.spotify.client"].count > 0;
    
    if (musicRunning) {
        [self queryAppleMusicPosition];
    } else if (spotifyRunning) {
        [self querySpotifyPosition];
    } else if (self.isPlaying) {
        self.isPlaying = NO;
        [Settings sharedSettings].isMusicPlaying = NO;
        if ([self.delegate respondsToSelector:@selector(musicDetectorPlaybackStateDidChange:)]) {
            [self.delegate musicDetectorPlaybackStateDidChange:NO];
        }
    }
}

- (void)queryAppleMusicPosition {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *src = @"tell application \"Music\"\n"
                        @"  try\n"
                        @"    if player state is playing then\n"
                        @"      set tName to name of current track\n"
                        @"      set tArtist to artist of current track\n"
                        @"      set tAlbum to album of current track\n"
                        @"      set tPos to player position\n"
                        @"      set tDur to duration of current track\n"
                        @"      return tName & \":::\" & tArtist & \":::\" & tAlbum & \":::\" & (tPos as string) & \":::\" & (tDur as string)\n"
                        @"    else\n"
                        @"      return \"PAUSED\"\n"
                        @"    end if\n"
                        @"  on error\n"
                        @"    return \"ERROR\"\n"
                        @"  end try\n"
                        @"end tell";
        NSAppleScript *s = [[NSAppleScript alloc] initWithSource:src];
        NSDictionary *err = nil;
        NSAppleEventDescriptor *res = [s executeAndReturnError:&err];
        NSString *str = [res stringValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([str isEqualToString:@"PAUSED"] || [str isEqualToString:@"ERROR"] || str.length == 0) {
                if (self.isPlaying) {
                    self.isPlaying = NO;
                    [Settings sharedSettings].isMusicPlaying = NO;
                    if ([self.delegate respondsToSelector:@selector(musicDetectorPlaybackStateDidChange:)]) {
                        [self.delegate musicDetectorPlaybackStateDidChange:NO];
                    }
                }
                return;
            }
            
            NSArray *parts = [str componentsSeparatedByString:@":::"];
            if (parts.count >= 5) {
                NSString *trackName = parts[0];
                NSString *artistName = parts[1];
                NSString *albumName = parts[2];
                NSTimeInterval pos = [parts[3] doubleValue];
                NSTimeInterval dur = [parts[4] doubleValue];
                
                [[LyricsManager sharedManager] updatePlaybackPosition:pos isPlaying:YES];
                
                if (![self.currentTrack isEqualToString:trackName] || ![self.currentArtist isEqualToString:artistName] || !self.isPlaying) {
                    [self updateTrack:trackName artist:artistName album:albumName genre:@"" isPlaying:YES duration:dur];
                }
            }
        });
    });
}

- (void)querySpotifyPosition {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *src = @"tell application \"Spotify\"\n"
                        @"  try\n"
                        @"    if player state is playing then\n"
                        @"      set tName to name of current track\n"
                        @"      set tArtist to artist of current track\n"
                        @"      set tAlbum to album of current track\n"
                        @"      set tPos to playback position\n"
                        @"      set tDur to (duration of current track) / 1000\n"
                        @"      return tName & \":::\" & tArtist & \":::\" & tAlbum & \":::\" & (tPos as string) & \":::\" & (tDur as string)\n"
                        @"    else\n"
                        @"      return \"PAUSED\"\n"
                        @"    end if\n"
                        @"  on error\n"
                        @"    return \"ERROR\"\n"
                        @"  end try\n"
                        @"end tell";
        NSAppleScript *s = [[NSAppleScript alloc] initWithSource:src];
        NSDictionary *err = nil;
        NSAppleEventDescriptor *res = [s executeAndReturnError:&err];
        NSString *str = [res stringValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([str isEqualToString:@"PAUSED"] || [str isEqualToString:@"ERROR"] || str.length == 0) {
                if (self.isPlaying) {
                    self.isPlaying = NO;
                    [Settings sharedSettings].isMusicPlaying = NO;
                    if ([self.delegate respondsToSelector:@selector(musicDetectorPlaybackStateDidChange:)]) {
                        [self.delegate musicDetectorPlaybackStateDidChange:NO];
                    }
                }
                return;
            }
            
            NSArray *parts = [str componentsSeparatedByString:@":::"];
            if (parts.count >= 5) {
                NSString *trackName = parts[0];
                NSString *artistName = parts[1];
                NSString *albumName = parts[2];
                NSTimeInterval pos = [parts[3] doubleValue];
                NSTimeInterval dur = [parts[4] doubleValue];
                
                [[LyricsManager sharedManager] updatePlaybackPosition:pos isPlaying:YES];
                
                if (![self.currentTrack isEqualToString:trackName] || ![self.currentArtist isEqualToString:artistName] || !self.isPlaying) {
                    [self updateTrack:trackName artist:artistName album:albumName genre:@"" isPlaying:YES duration:dur];
                }
            }
        });
    });
}

@end
