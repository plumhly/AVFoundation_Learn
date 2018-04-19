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
#import "THThumbnail.h"
#import <AVFoundation/AVFoundation.h>
#import "THTransport.h"
#import "THPlayerView.h"
#import "AVAsset+THAdditions.h"
#import "UIAlertView+THAdditions.h"
#import "THNotifications.h"
#import "THThumbnail.h"

// AVPlayerItem's status property
#define STATUS_KEYPATH @"status"

// Refresh interval for timed observations of AVPlayer
#define REFRESH_INTERVAL 0.5f

// Define this constant for the key-value observation context.
static const NSString *PlayerItemStatusContext;


@interface THPlayerController () <THTransportDelegate>

@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayer *player;
@property (strong, nonatomic) THPlayerView *playerView;

@property (nonatomic, weak) id <THTransport> transport;

@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) id itemEndObserver;
@property (nonatomic, assign) float lastPlayBackRate;

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;

@end

@implementation THPlayerController

#pragma mark - Setup

- (id)initWithURL:(NSURL *)assetURL {
    self = [super init];
    if (self) {
        
        // Listing 4.6
        _asset = [AVAsset assetWithURL:assetURL];
        [self prepareToPlay];
        
    }
    return self;
}

- (void)prepareToPlay {

    // Listing 4.6
    NSArray *keys = @[@"tracks", @"duration", @"commonMetadata", @"availableMediaCharacteristicsWithMediaSelectionOptions"];
    _playerItem = [AVPlayerItem playerItemWithAsset:_asset automaticallyLoadedAssetKeys:keys];
    [_playerItem addObserver:self forKeyPath:STATUS_KEYPATH options:0 context:&PlayerItemStatusContext];
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    _playerView = [[THPlayerView alloc] initWithPlayer:_player];
    
    _transport = _playerView.transport;
    _transport.delegate = self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    // Listing 4.7
    if (context == &PlayerItemStatusContext) {
        // 在block里面,显式标注self
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_playerItem removeObserver:self forKeyPath:STATUS_KEYPATH];
            if (self->_playerItem.status == AVPlayerStatusReadyToPlay) {
                [self addPlayerItemTimeObserver];
                [self addItemEndObserverForPlayerItem];
                CMTime duration = self->_playerItem.duration;
                [self->_transport setCurrentTime:CMTimeGetSeconds(kCMTimeZero) duration:CMTimeGetSeconds(duration)];
                [self->_transport setTitle:self.asset.title];
                [self.player play];
                [self generateThumbnails];
                [self loadMediaOptions];
            } else {
                [UIAlertController alertControllerWithTitle:@"Error" message:@"Failed to load vedio" preferredStyle: UIAlertControllerStyleAlert];
            }
        });
    }
}


#pragma mark - Time Observers

- (void)addPlayerItemTimeObserver {

    // Listing 4.8
    CMTime intervel = CMTimeMakeWithSeconds(REFRESH_INTERVAL, NSEC_PER_SEC);
    dispatch_queue_t mainqueue = dispatch_get_main_queue();
    __weak typeof(self) _weakSelf = self;
    void (^callback)(CMTime time) = ^(CMTime time) {
        NSTimeInterval currentTime = CMTimeGetSeconds(time);
        NSTimeInterval duration = CMTimeGetSeconds(_weakSelf.playerItem.duration);
        [_weakSelf.transport setCurrentTime:currentTime duration:duration];
    };
    
    _timeObserver = [self.player addPeriodicTimeObserverForInterval:intervel
                                                              queue:mainqueue
                                                         usingBlock:callback];
    
}

- (void)addItemEndObserverForPlayerItem {

    // Listing 4.9
    NSString *name = AVPlayerItemDidPlayToEndTimeNotification;
    NSOperationQueue *main = [NSOperationQueue mainQueue];
    __weak typeof(self) _weakSelf = self;
    void(^callback)(NSNotification *noti) = ^(NSNotification *noti) {
        [_weakSelf.playerItem seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
            if (finished) {
                [_weakSelf.transport playbackComplete];
            }
        }];
    };
    _itemEndObserver = [[NSNotificationCenter defaultCenter]
                        addObserverForName:name
                        object:self.playerItem
                        queue:main
                        usingBlock:callback];
    
}

- (void)dealloc {
    if (_itemEndObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_itemEndObserver];
        _itemEndObserver = nil;
    }
}

#pragma mark - THTransportDelegate Methods

- (void)play {

    // Listing 4.10
    [self.player play];
}

- (void)pause {

    // Listing 4.10
    self.lastPlayBackRate = self.player.rate;
    [self.player pause];
}

- (void)stop {

    // Listing 4.10
    self.player.rate = 0;
    [self.transport playbackComplete];
}

- (void)jumpedToTime:(NSTimeInterval)time {

    // Listing 4.10
    [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
}

- (void)scrubbingDidStart {

    // Listing 4.11
    self.lastPlayBackRate = self.player.rate;
    [self.player pause];
    [self.player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
}

- (void)scrubbedToTime:(NSTimeInterval)time {

    // Listing 4.11
    [self.playerItem cancelPendingSeeks];
    [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
}

- (void)scrubbingDidEnd {

    // Listing 4.11
    [self addPlayerItemTimeObserver];
    if (self.lastPlayBackRate > 0) {
        [self.player play];
    }
}


#pragma mark - Thumbnail Generation

- (void)generateThumbnails {

    // Listing 4.14
    self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
    self.imageGenerator.maximumSize = CGSizeMake(200, 0);
    CMTime duration = self.asset.duration;
    
    NSMutableArray *times = [NSMutableArray array];
    CMTimeValue inscrement = duration.value / 20;
    CMTimeValue currentTime = kCMTimeZero.value;
    while (currentTime <= duration.value) {
        CMTime time = CMTimeMake(currentTime, duration.timescale);
        NSValue *value = [NSValue valueWithCMTime:time];
        [times addObject:value];
        currentTime += inscrement;
    }
    
    NSMutableArray *images = [NSMutableArray array];
    __block NSInteger count = times.count;
    
    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        if (result == AVAssetImageGeneratorSucceeded) {
            UIImage *img = [UIImage imageWithCGImage:image];
            id thumbnail = [THThumbnail thumbnailWithImage:img time:actualTime];
            [images addObject:thumbnail];
        } else {
            NSLog(@"Failed to create thumbnail");
        }
        
        if (--count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:THThumbnailsGeneratedNotification object:images];
            });
        }
    }];
    
}


- (void)loadMediaOptions {

    // Listing 4.16
    NSString *mc = AVMediaCharacteristicLegible;
    AVMediaSelectionGroup *group = [self.asset mediaSelectionGroupForMediaCharacteristic:mc];
    if (group) {
        NSMutableArray *subtitles = [NSMutableArray array];
        for (AVMediaSelectionOption *option in group.options) {
            [subtitles addObject:option.displayName];
        }
        [self.transport setSubtitles:subtitles];
    } else {
        [self.transport setSubtitles:nil];
    }
    
}

- (void)subtitleSelected:(NSString *)subtitle {

    // Listing 4.17
    AVMediaSelectionGroup *group = [self.asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
    BOOL isSelect = NO;
    for (AVMediaSelectionOption *option in group.options) {
        if ([option.displayName isEqualToString:subtitle]) {
            [self.playerItem selectMediaOption:option inMediaSelectionGroup:group];
            isSelect = YES;
        }
    }
    
    if (!isSelect) {
        [_playerItem selectMediaOption:nil inMediaSelectionGroup:group];
    }
    
}


#pragma mark - Housekeeping

- (UIView *)view {
    return self.playerView;
}

@end
