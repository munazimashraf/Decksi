#import "AudioEngine.h"
#import "Settings.h"
#import <Accelerate/Accelerate.h>
#import <CoreMedia/CoreMedia.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>

static const int kFFTSize = 1024;
static const int kLog2N   = 10;

@interface AudioEngine () {
    FFTSetup _fftSetup;
    DSPSplitComplex _splitComplex;
    float *_realp;
    float *_imagp;
    float *_magnitudes;
    float *_window;
    
    // Beat detection state
    float _bassHistory[32];
    int _bassHistoryIndex;
    float _bassAverage;
    
    // Audio FFT ring buffer
    float _audioRingBuffer[kFFTSize];
    int _audioRingCount;
}

@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) BOOL isInternalSystemAudio;
@property (nonatomic, assign) CGFloat currentBeatLevel;
@property (nonatomic, assign) CGFloat currentBassLevel;
@property (nonatomic, assign) CGFloat currentMidLevel;
@property (nonatomic, assign) CGFloat currentHighLevel;
@property (nonatomic, assign) CGFloat currentRMS;

// Internal System Audio (ScreenCaptureKit)
@property (nonatomic, strong) SCStream *scStream;
@property (nonatomic, strong) dispatch_queue_t audioQueue;

// Optional Fallback Engine (Mic)
@property (nonatomic, strong) AVAudioEngine *engine;

// Demo Beat Simulator
@property (nonatomic, strong) NSTimer *demoTimer;
@property (nonatomic, strong) NSTimer *decayTimer;
@property (nonatomic, strong) NSTimer *permissionCheckTimer;
@property (nonatomic, assign) CGFloat demoPhase;

@end

@implementation AudioEngine

+ (instancetype)sharedEngine {
    static AudioEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AudioEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fftSetup = vDSP_create_fftsetup(kLog2N, kFFTRadix2);
        _realp = (float *)malloc(sizeof(float) * (kFFTSize / 2));
        _imagp = (float *)malloc(sizeof(float) * (kFFTSize / 2));
        _magnitudes = (float *)malloc(sizeof(float) * (kFFTSize / 2));
        _splitComplex.realp = _realp;
        _splitComplex.imagp = _imagp;
        
        _window = (float *)malloc(sizeof(float) * kFFTSize);
        vDSP_hann_window(_window, kFFTSize, vDSP_HANN_NORM);
        
        memset(_bassHistory, 0, sizeof(_bassHistory));
        _bassHistoryIndex = 0;
        _bassAverage = 0.01;
        
        memset(_audioRingBuffer, 0, sizeof(_audioRingBuffer));
        _audioRingCount = 0;
        
        _currentBeatLevel = 0.0;
        _currentBassLevel = 0.0;
        _currentMidLevel = 0.0;
        _currentHighLevel = 0.0;
        _currentRMS = 0.0;
        _demoPhase = 0.0;
        _isInternalSystemAudio = NO;
        
        _audioQueue = dispatch_queue_create("in.decksi.audioqueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self stop];
    if (_fftSetup) vDSP_destroy_fftsetup(_fftSetup);
    if (_realp) free(_realp);
    if (_imagp) free(_imagp);
    if (_magnitudes) free(_magnitudes);
    if (_window) free(_window);
}

- (BOOL)start {
    if (self.isRunning) return YES;
    
    // Smooth decay timer (60 FPS)
    __weak typeof(self) weakSelf = self;
    self.decayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf updateDecay];
    }];
    
    AudioSourceMode source = [Settings sharedSettings].audioSource;
    if (source == AudioSourceModeDemoSimulator) {
        [self startDemoSimulator];
        self.isRunning = YES;
        return YES;
    } else if (source == AudioSourceModeMicrophone) {
        return [self startMicrophoneCapture];
    }
    
    // Default & Preferred: Native Internal System Audio (NO microphone!)
    return [self startInternalSystemAudioCapture];
}

- (void)stop {
    if (self.demoTimer) {
        [self.demoTimer invalidate];
        self.demoTimer = nil;
    }
    if (self.decayTimer) {
        [self.decayTimer invalidate];
        self.decayTimer = nil;
    }
    if (self.permissionCheckTimer) {
        [self.permissionCheckTimer invalidate];
        self.permissionCheckTimer = nil;
    }
    if (self.scStream) {
        [self.scStream stopCaptureWithCompletionHandler:nil];
        self.scStream = nil;
    }
    if (self.engine) {
        @try {
            [self.engine.inputNode removeTapOnBus:0];
            [self.engine stop];
        } @catch (NSException *e) {}
        self.engine = nil;
    }
    self.isInternalSystemAudio = NO;
    self.isRunning = NO;
}

- (void)switchMode:(NSInteger)mode {
    [self stop];
    [Settings sharedSettings].audioSource = (AudioSourceMode)mode;
    [[Settings sharedSettings] saveSettings];
    [self start];
}

- (void)updateDecay {
    if (self.currentBeatLevel > 0.01) {
        self.currentBeatLevel *= 0.86;
    } else {
        self.currentBeatLevel = 0.0;
    }
    self.currentBassLevel *= 0.91;
    self.currentMidLevel  *= 0.91;
    self.currentHighLevel *= 0.91;
    self.currentRMS       *= 0.91;
}

#pragma mark - Native Internal System Audio Capture (ScreenCaptureKit - NO MICROPHONE)

- (BOOL)startInternalSystemAudioCapture {
    NSLog(@"Starting native Internal System Audio capture (Zero microphone)...");
    self.isInternalSystemAudio = YES;
    
    if (self.permissionCheckTimer) {
        [self.permissionCheckTimer invalidate];
        self.permissionCheckTimer = nil;
    }
    
    BOOL hasPermission = CGPreflightScreenCaptureAccess();
    if (!hasPermission) {
        // Listen passively in background: as soon as user enables permission in System Settings, auto-start!
        __weak typeof(self) weakSelf = self;
        self.permissionCheckTimer = [NSTimer scheduledTimerWithTimeInterval:2.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            if (CGPreflightScreenCaptureAccess()) {
                NSLog(@"✅ System audio recording permission detected! Switching to pure internal capture...");
                [timer invalidate];
                weakSelf.permissionCheckTimer = nil;
                if (weakSelf.demoTimer) {
                    [weakSelf.demoTimer invalidate];
                    weakSelf.demoTimer = nil;
                }
                [weakSelf startInternalSystemAudioCapture];
            }
        }];
    }
    
    __weak typeof(self) weakSelf = self;
    [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable shareableContent, NSError * _Nullable error) {
        if (error || !shareableContent || shareableContent.displays.count == 0) {
            NSLog(@"ScreenCaptureKit unavailable (%@). Falling back to internal music tempo rhythm.", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf startDemoSimulator];
                weakSelf.isRunning = YES;
            });
            return;
        }
        
        SCDisplay *display = shareableContent.displays.firstObject;
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
        
        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        config.capturesAudio = YES;
        config.excludesCurrentProcessAudio = YES;
        config.sampleRate = 44100;
        config.channelCount = 2;
        // Audio-only optimization: minimal 16x16 video dimension to consume zero GPU/video memory
        config.width = 16;
        config.height = 16;
        config.minimumFrameInterval = CMTimeMake(1, 1);
        
        NSError *streamErr = nil;
        SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:config delegate:weakSelf];
        [stream addStreamOutput:weakSelf type:SCStreamOutputTypeScreen sampleHandlerQueue:weakSelf.audioQueue error:nil];
        [stream addStreamOutput:weakSelf type:SCStreamOutputTypeAudio sampleHandlerQueue:weakSelf.audioQueue error:&streamErr];
        
        if (streamErr) {
            NSLog(@"Failed to add audio stream output: %@", streamErr);
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf startDemoSimulator];
                weakSelf.isRunning = YES;
            });
            return;
        }
        
        [stream startCaptureWithCompletionHandler:^(NSError * _Nullable startErr) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (startErr) {
                    NSLog(@"Internal system audio capture permission/start notice: %@. Using internal music rhythm.", startErr);
                    [weakSelf startDemoSimulator];
                } else {
                    NSLog(@"✅ Decksi is now capturing pure internal system audio directly from your Mac's audio output!");
                    if (weakSelf.permissionCheckTimer) {
                        [weakSelf.permissionCheckTimer invalidate];
                        weakSelf.permissionCheckTimer = nil;
                    }
                    if (weakSelf.demoTimer) {
                        [weakSelf.demoTimer invalidate];
                        weakSelf.demoTimer = nil;
                    }
                    weakSelf.scStream = stream;
                }
                weakSelf.isRunning = YES;
            });
        }];
    }];
    
    self.isRunning = YES;
    return YES;
}

#pragma mark - SCStreamOutput Protocol (Receives Internal Audio Frames)

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type == SCStreamOutputTypeScreen) {
        // Discard dummy video frame with zero processing
        return;
    }
    if (type != SCStreamOutputTypeAudio) return;
    
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer = NULL;
    
    OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer,
        NULL,
        &audioBufferList,
        sizeof(audioBufferList),
        NULL,
        NULL,
        0,
        &blockBuffer
    );
    
    if (status == noErr && audioBufferList.mNumberBuffers > 0) {
        float *samples = (float *)audioBufferList.mBuffers[0].mData;
        UInt32 numBytes = audioBufferList.mBuffers[0].mDataByteSize;
        UInt32 numSamples = numBytes / sizeof(float);
        
        if (samples && numSamples > 0) {
            for (UInt32 i = 0; i < numSamples; i++) {
                _audioRingBuffer[_audioRingCount++] = samples[i];
                if (_audioRingCount >= kFFTSize) {
                    [self processFloatSamples:_audioRingBuffer count:kFFTSize];
                    // Overlap by 50% for high-speed responsive 60fps tracking
                    memmove(_audioRingBuffer, _audioRingBuffer + (kFFTSize / 2), sizeof(float) * (kFFTSize / 2));
                    _audioRingCount = kFFTSize / 2;
                }
            }
        }
    }
    
    if (blockBuffer) {
        CFRelease(blockBuffer);
    }
}

#pragma mark - Fallback Microphone (Only if user explicitly chose it)

- (BOOL)startMicrophoneCapture {
    NSLog(@"Starting optional microphone capture...");
    self.engine = [[AVAudioEngine alloc] init];
    AVAudioInputNode *input = self.engine.inputNode;
    AVAudioFormat *format = [input inputFormatForBus:0];
    
    if (format.sampleRate == 0 || format.channelCount == 0) {
        [self startDemoSimulator];
        self.isRunning = YES;
        return YES;
    }
    
    __weak typeof(self) weakSelf = self;
    @try {
        [input installTapOnBus:0
                    bufferSize:kFFTSize
                        format:format
                         block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
            if (buffer.floatChannelData && buffer.frameLength >= kFFTSize) {
                [weakSelf processFloatSamples:buffer.floatChannelData[0] count:kFFTSize];
            }
        }];
        NSError *err = nil;
        [self.engine startAndReturnError:&err];
        if (err) [self startDemoSimulator];
    } @catch (NSException *e) {
        [self startDemoSimulator];
    }
    
    self.isRunning = YES;
    return YES;
}

#pragma mark - Fast Fourier Transform & Beat Detection

- (void)processFloatSamples:(float *)samples count:(uint32_t)count {
    if (!samples || count < kFFTSize) return;
    
    float windowedSamples[kFFTSize];
    vDSP_vmul(samples, 1, _window, 1, windowedSamples, 1, kFFTSize);
    
    float rms = 0.0;
    vDSP_rmsqv(windowedSamples, 1, &rms, kFFTSize);
    
    vDSP_ctoz((DSPComplex *)windowedSamples, 2, &_splitComplex, 1, kFFTSize / 2);
    vDSP_fft_zrip(_fftSetup, &_splitComplex, 1, kLog2N, kFFTDirection_Forward);
    vDSP_zvmags(&_splitComplex, 1, _magnitudes, 1, kFFTSize / 2);
    
    float scale = 1.0f / (float)(kFFTSize * 2);
    vDSP_vsmul(_magnitudes, 1, &scale, _magnitudes, 1, kFFTSize / 2);
    
    // Frequency Bins:
    // Bass: 1-6 (20-250 Hz)
    float bassSum = 0.0;
    for (int i = 1; i <= 6; i++) bassSum += _magnitudes[i];
    float bassEnergy = sqrtf(bassSum / 6.0f);
    
    // Mids: 7-58 (250-2500 Hz)
    float midSum = 0.0;
    for (int i = 7; i <= 58; i++) midSum += _magnitudes[i];
    float midEnergy = sqrtf(midSum / 51.0f);
    
    // Highs: 59-250 (2500-11000 Hz)
    float highSum = 0.0;
    for (int i = 59; i <= 250; i++) highSum += _magnitudes[i];
    float highEnergy = sqrtf(highSum / 191.0f);
    
    CGFloat sensitivity = [Settings sharedSettings].sensitivity;
    bassEnergy *= (float)sensitivity;
    midEnergy  *= (float)sensitivity;
    highEnergy *= (float)sensitivity;
    rms        *= (float)sensitivity;
    
    // Dynamic Adaptive Beat Detection
    _bassHistory[_bassHistoryIndex] = bassEnergy;
    _bassHistoryIndex = (_bassHistoryIndex + 1) % 32;
    
    float sum = 0.0;
    for (int i = 0; i < 32; i++) sum += _bassHistory[i];
    _bassAverage = sum / 32.0f;
    if (_bassAverage < 0.005f) _bassAverage = 0.005f;
    
    float thresholdMultiplier = 1.25f - (float)(sensitivity - 1.0) * 0.2f;
    if (thresholdMultiplier < 1.05f) thresholdMultiplier = 1.05f;
    float threshold = _bassAverage * thresholdMultiplier;
    
    BOOL isBeat = (bassEnergy > threshold) && (bassEnergy > 0.015f);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentBassLevel = fminf(fmaxf(bassEnergy * 2.0f, 0.0f), 1.0f);
        self.currentMidLevel  = fminf(fmaxf(midEnergy * 3.0f, 0.0f), 1.0f);
        self.currentHighLevel = fminf(fmaxf(highEnergy * 4.0f, 0.0f), 1.0f);
        self.currentRMS       = fminf(fmaxf(rms * 4.0f, 0.0f), 1.0f);
        
        if (isBeat) {
            float intensity = fminf((bassEnergy - threshold) / (_bassAverage + 0.01f), 1.0f);
            CGFloat reactFactor = [Settings sharedSettings].reactivity;
            self.currentBeatLevel = fminf(0.5f + intensity * 0.5f * reactFactor, 1.0f);
            
            if ([self.delegate respondsToSelector:@selector(audioEngineDidDetectBeatWithIntensity:)]) {
                [self.delegate audioEngineDidDetectBeatWithIntensity:self.currentBeatLevel];
            }
        }
        
        if ([self.delegate respondsToSelector:@selector(audioEngineDidUpdateLevelsBass:mid:high:rms:)]) {
            [self.delegate audioEngineDidUpdateLevelsBass:self.currentBassLevel
                                                     mid:self.currentMidLevel
                                                    high:self.currentHighLevel
                                                     rms:self.currentRMS];
        }
    });
}

#pragma mark - Demo Beat Simulator

- (void)startDemoSimulator {
    __weak typeof(self) weakSelf = self;
    self.demoTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf tickDemoSimulator];
    }];
    NSLog(@"Demo Beat Simulator running (124 BPM sync)");
}

- (void)tickDemoSimulator {
    self.demoPhase += 0.040;
    
    BOOL isMusicPlaying = [Settings sharedSettings].isMusicPlaying;
    BOOL isExplicitDemo = ([Settings sharedSettings].audioSource == AudioSourceModeDemoSimulator);
    
    // When music is paused and not in explicit demo mode, breathe calmly instead of blasting beats
    if (!isMusicPlaying && !isExplicitDemo) {
        self.currentBassLevel = 0.08f + 0.04f * sinf(self.demoPhase * 0.4f);
        self.currentMidLevel  = 0.06f;
        self.currentHighLevel = 0.04f;
        self.currentRMS       = 0.06f;
        self.currentBeatLevel = 0.0f;
        return;
    }
    
    float beatWave = sinf(self.demoPhase);
    
    self.currentBassLevel = fabsf(sinf(self.demoPhase)) * 0.70 + fabsf(sinf(self.demoPhase * 0.5)) * 0.30;
    self.currentMidLevel  = fabsf(sinf(self.demoPhase * 1.5)) * 0.60;
    self.currentHighLevel = fabsf(cosf(self.demoPhase * 2.3)) * 0.50;
    self.currentRMS       = (self.currentBassLevel * 0.5 + self.currentMidLevel * 0.3 + self.currentHighLevel * 0.2);
    
    if (beatWave > 0.88) {
        self.currentBeatLevel = 0.95;
        self.currentBassLevel = 1.0;
        if ([self.delegate respondsToSelector:@selector(audioEngineDidDetectBeatWithIntensity:)]) {
            [self.delegate audioEngineDidDetectBeatWithIntensity:self.currentBeatLevel];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(audioEngineDidUpdateLevelsBass:mid:high:rms:)]) {
        [self.delegate audioEngineDidUpdateLevelsBass:self.currentBassLevel
                                                 mid:self.currentMidLevel
                                                high:self.currentHighLevel
                                                 rms:self.currentRMS];
    }
}

@end
