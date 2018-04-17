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


// Listing 4.4

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
    NSArray *keys = @[@"tracks", @"duration", @"commonMetadata"];
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
        _timeObserver = nil;
    }
}

#pragma mark - THTransportDelegate Methods

- (void)play {

    // Listing 4.10
    
}

- (void)pause {

    // Listing 4.10
    
}

- (void)stop {

    // Listing 4.10
    
}

- (void)jumpedToTime:(NSTimeInterval)time {

    // Listing 4.10
    
}

- (void)scrubbingDidStart {

    // Listing 4.11
}

- (void)scrubbedToTime:(NSTimeInterval)time {

    // Listing 4.11
    
}

- (void)scrubbingDidEnd {

    // Listing 4.11
    
}


#pragma mark - Thumbnail Generation

- (void)generateThumbnails {

    // Listing 4.14

}


- (void)loadMediaOptions {

    // Listing 4.16
    
}

- (void)subtitleSelected:(NSString *)subtitle {

    // Listing 4.17
    
}


#pragma mark - Housekeeping

- (UIView *)view {
    return self.playerView;
}

@end
