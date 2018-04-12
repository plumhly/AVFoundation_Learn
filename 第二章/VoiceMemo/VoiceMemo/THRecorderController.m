//
//  MIT License
//
//  Copyright (c) 2014 Bob McCune http://bobmccune.com/
//  Copyright (c) 2014 TapHarmonic, LLC http://tapharmonic.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "THRecorderController.h"
#import <AVFoundation/AVFoundation.h>
#import "THMemo.h"
#import "THLevelPair.h"
#import "THMeterTable.h"

@interface THRecorderController () <AVAudioRecorderDelegate>

@property (strong, nonatomic) AVAudioPlayer *player;
@property (strong, nonatomic) AVAudioRecorder *recorder;
@property (strong, nonatomic) THRecordingStopCompletionHandler completionHandler;
@property (nonatomic, strong) THMeterTable *meterTable;

@end

@implementation THRecorderController

- (id)init {
    self = [super init];
    if (self) {
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"memo.caf"];
        NSURL *pathURL = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        
        NSDictionary *settings = @{
                                   AVFormatIDKey: @(kAudioFormatAppleIMA4),
                                   AVSampleRateKey: @44100.0f,
                                   AVNumberOfChannelsKey: @1,
                                   AVEncoderBitDepthHintKey: @16,
                                   AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
                                   };
        
        _recorder = [[AVAudioRecorder alloc] initWithURL:pathURL settings:settings error:&error];
        [_recorder addObserver:self forKeyPath:@"currentTime" options:NSKeyValueObservingOptionNew context:nil];
        if (_recorder) {
            _recorder.delegate = self;
            _recorder.meteringEnabled = YES;
            [_recorder prepareToRecord];
        } else {
            NSLog(@"Recorder create Error: %@", error.localizedDescription);
        }
        _meterTable = [[THMeterTable alloc] init];
    }
    return self;
}

- (BOOL)record {
    BOOL record = [_recorder record];
    return record;
}

- (void)pause {
    [_recorder pause];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"");
}

- (void)stopWithCompletionHandler:(THRecordingStopCompletionHandler)handler {
    _completionHandler = handler;
    [_recorder stop];
}

- (void)saveRecordingWithName:(NSString *)name completionHandler:(THRecordingSaveCompletionHandler)handler {
    NSTimeInterval timestamp = [NSDate timeIntervalSinceReferenceDate];
    NSString *path = [NSString stringWithFormat:@"%@-%f.caf",name, timestamp];
    NSString *finnalPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:path];
    NSURL *finalURL = [NSURL fileURLWithPath:finnalPath];
    NSURL *scrURL = _recorder.url;
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] copyItemAtURL:scrURL toURL:finalURL error:&error];
    
    if (success) {
        handler(YES, [THMemo memoWithTitle:name url:finalURL]);
        [_recorder prepareToRecord];
    } else {
        handler(NO, error);
        NSLog(@"Copy Item error: %@", error.localizedDescription);
    }
}

- (THLevelPair *)levels {
    [_recorder updateMeters];
    float avgPower = [_recorder averagePowerForChannel:0];
    float peakPower = [_recorder peakPowerForChannel:0];
    
    float linearLeave = [_meterTable valueForPower:avgPower];
    float linearPeak = [_meterTable valueForPower:peakPower];
    return [[THLevelPair alloc] initWithLevel:linearLeave peakLevel:linearPeak];
}

- (NSString *)formattedCurrentTime {
    NSUInteger time = (NSUInteger)_recorder.currentTime;
    
    NSUInteger hour = time / 3600;
    NSUInteger minute = (time / 60) % 60;
    NSUInteger secod = time % 60;
    return [NSString stringWithFormat:@"%02lu:%02lu:%02lu", (unsigned long)hour, (unsigned long)minute, (unsigned long)secod];
}

- (BOOL)playbackMemo:(THMemo *)memo {
    [self.player stop];
    _player = [[AVAudioPlayer alloc] initWithContentsOfURL:memo.url error:nil];
    if (_player) {
        [_player play];
        return YES;
    }
    return NO;
}

#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)success {
    if (_completionHandler) {
        _completionHandler(success);
    }
}

@end
