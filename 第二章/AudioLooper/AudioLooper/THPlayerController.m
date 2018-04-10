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

#import "THPlayerController.h"
#import <AVFoundation/AVFoundation.h>

@interface THPlayerController()
@property (nonatomic, strong) NSArray *players;
@end

@implementation THPlayerController

- (instancetype)init
{
    self = [super init];
    if (self) {
        AVAudioPlayer *guitarPlayer = [self playerForFile:@"guitar"];
        AVAudioPlayer *bassPlayer = [self playerForFile:@"bass"];
        AVAudioPlayer *drumsPlayer = [self playerForFile:@"drums"];
        _players = @[guitarPlayer, bassPlayer, drumsPlayer];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
        [center addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    }
    return self;
}

- (void)handleRouteChange:(NSNotification *)notification {
    NSDictionary *dic = notification.userInfo;
    AVAudioSessionRouteChangeReason reson = [dic[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reson == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *routeDescription = dic[AVAudioSessionRouteChangePreviousRouteKey];
        AVAudioSessionPortDescription *portDescription = routeDescription.outputs.firstObject;
        if ([portDescription.portType isEqualToString: AVAudioSessionPortHeadphones]) {
            [self stop];
            if (self.delegate) {
                [self.delegate playbackStopped];
            }
        }
    }
}

- (void)handleInterruption:(NSNotification *)notification {
    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        [self stop];
        if (self.delegate) {
            [self.delegate playbackStopped];
        }
    } else {
        //AVAudioSessionInterruptionTypeEnd
        AVAudioSessionInterruptionOptions option = [notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (option == AVAudioSessionInterruptionOptionShouldResume) {
            [self play];
            if (self.delegate) {
                [self.delegate playbackBegan];
            }
        }
    }
}

- (AVAudioPlayer *)playerForFile:(NSString *)name {
    NSURL *file = [[NSBundle mainBundle] URLForResource:name withExtension:@"caf"];
    NSError *error = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:file error:&error];
    if (player) {
        player.numberOfLoops = -1;
        player.enableRate = YES;//是否启用播放速率调整
        [player prepareToPlay];
    } else {
        NSLog(@"error create player: %@", [error localizedDescription]);
    }
    return player;
}

- (void)play {
    if (!self.isPlaying) {
        NSTimeInterval delayTime = [_players[0] deviceCurrentTime] + 0.01;
        for (AVAudioPlayer *player in _players) {
            [player playAtTime:delayTime];
        }
        self.playing = YES;
    }
}

- (void)stop {
    if (self.isPlaying) {
        for (AVAudioPlayer *player in _players) {
            [player stop];
            player.currentTime = 0.0f;
        }
        self.playing = NO;
    }
}

- (void)adjustRate:(float)rate {
    for (AVAudioPlayer *player in _players) {
        player.rate = rate;//播放速率
    }
}

- (void)adjustPan:(float)pan forPlayerAtIndex:(NSUInteger)index {
    if ([self isValidIndex:index]) {
        AVAudioPlayer *player = _players[index];
        player.pan = pan;//立体声 -1 0 1
    }
}

- (void)adjustVolume:(float)volume forPlayerAtIndex:(NSUInteger)index {
    if ([self isValidIndex:index]) {
        AVAudioPlayer *player = _players[index];
        player.volume = volume;//音量
    }
}

- (BOOL)isValidIndex:(NSUInteger)index {
    return index < _players.count;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
