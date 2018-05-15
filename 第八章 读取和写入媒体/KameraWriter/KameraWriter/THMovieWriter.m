//
//  MIT License
//
//  Copyright (c) 2015 Bob McCune http://bobmccune.com/
//  Copyright (c) 2015 TapHarmonic, LLC http://tapharmonic.com/
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

#import "THMovieWriter.h"
#import <AVFoundation/AVFoundation.h>
#import "THContextManager.h"
#import "THFunctions.h"
#import "THPhotoFilters.h"
#import "THNotifications.h"

static NSString *const THVideoFilename = @"movie.mov";

@interface THMovieWriter ()

@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterVideoInput;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterAudioInput;
@property (strong, nonatomic)
    AVAssetWriterInputPixelBufferAdaptor *assetWriterInputPixelBufferAdaptor;

@property (strong, nonatomic) dispatch_queue_t dispatchQueue;

@property (weak, nonatomic) CIContext *ciContext;
@property (nonatomic) CGColorSpaceRef colorSpace;
@property (strong, nonatomic) CIFilter *activeFilter;

@property (strong, nonatomic) NSDictionary *videoSettings;
@property (strong, nonatomic) NSDictionary *audioSettings;

@property (nonatomic) BOOL firstSample;

@end

@implementation THMovieWriter

- (id)initWithVideoSettings:(NSDictionary *)videoSettings
			  audioSettings:(NSDictionary *)audioSettings
              dispatchQueue:(dispatch_queue_t)dispatchQueue {

	self = [super init];
	if (self) {

        // Listing 8.13
        _videoSettings = videoSettings;
        _audioSettings = audioSettings;
        _dispatchQueue = dispatchQueue;
        
        _ciContext = [THContextManager sharedInstance].ciContext;
        _colorSpace = CGColorSpaceCreateDeviceRGB();
        _activeFilter = [THPhotoFilters defaultFilter];
        _firstSample = YES;
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(filterChanged:) name:THFilterSelectionChangedNotification object:nil];

    }
	return self;
}

- (void)dealloc {

    // Listing 8.13
    CGColorSpaceRelease(_colorSpace);
    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

- (void)filterChanged:(NSNotification *)notification {

    // Listing 8.13
    self.activeFilter = [notification.object copy];

}

- (void)startWriting {

    // Listing 8.14
    dispatch_async(self.dispatchQueue, ^{
        NSError *error = nil;
        self.assetWriter = [[AVAssetWriter alloc] initWithURL:[self outputURL] fileType:AVFileTypeQuickTimeMovie error:&error];
        if (!self.assetWriter && error) {
            NSLog(@"crete assetwriter failed with error: %@", error.localizedDescription);
            return;
        }
        self.assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:self.videoSettings];
        self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        
        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        self.assetWriterVideoInput.transform = THTransformForDeviceOrientation(orientation);
        
        NSDictionary *attributes = @{
                                   (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                   (id)kCVPixelBufferWidthKey: self.videoSettings[AVVideoWidthKey],
                                   (id)kCVPixelBufferHeightKey: self.videoSettings[AVVideoHeightKey],
                                   (id)kCVPixelFormatOpenGLCompatibility: (id)kCFBooleanTrue
                                   };
        
        self.assetWriterInputPixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.assetWriterVideoInput sourcePixelBufferAttributes:attributes];
        
        if ([self.assetWriter canAddInput:self.assetWriterVideoInput]) {
            [self.assetWriter addInput:self.assetWriterVideoInput];
        } else {
            NSLog(@"add video input error");
            return;
        }
        
        self.assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:self.audioSettings];
        self.assetWriterAudioInput.expectsMediaDataInRealTime = YES;
        if ([self.assetWriter canAddInput:self.assetWriterAudioInput]) {
            [self.assetWriter addInput:self.assetWriterAudioInput];
        } else {
            NSLog(@"add audio input error");
            return;
        }
        self.firstSample = YES;
        self.isWriting = YES;
    });
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer {

    // Listing 8.15
    if (!self.isWriting) {
        return;
    }
    
    CMFormatDescriptionRef description = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMMediaType type = CMFormatDescriptionGetMediaType(description);
    if (type == kCMMediaType_Video) {
        CMTime timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if (self.firstSample) {
            if ([self.assetWriter startWriting]) {
                [self.assetWriter startSessionAtSourceTime:timeStamp];
            } else {
                NSLog(@"assetWriter start error");
            }
            self.firstSample = NO;
        }
        
        CVPixelBufferRef renderBuffer = NULL;
        CVPixelBufferPoolRef bufferPool = self.assetWriterInputPixelBufferAdaptor.pixelBufferPool;
        CVReturn result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,  bufferPool, &renderBuffer);
        if (result != kCVReturnSuccess) {
            NSLog(@"CVPixelBufferPoolCreatePixelBuffer error");
            return;
        }
        
        CVPixelBufferRef pixref = CMSampleBufferGetImageBuffer(sampleBuffer);
        CIImage *image = [CIImage imageWithCVPixelBuffer:pixref];
        [self.activeFilter setValue:image forKey:kCIInputImageKey];
        CIImage *souceImage = self.activeFilter.outputImage;
        if (!souceImage) {
            souceImage = image;
        }
        [self.ciContext render:souceImage toCVPixelBuffer:renderBuffer bounds:souceImage.extent colorSpace:self.colorSpace];
        if (self.assetWriterVideoInput.isReadyForMoreMediaData) {
            if (![self.assetWriterInputPixelBufferAdaptor appendPixelBuffer:renderBuffer withPresentationTime:timeStamp]) {
                NSLog(@"assetWriterInputPixelBufferAdaptor appendPixelBuffer error");
            }
        }
        CVPixelBufferRelease(renderBuffer);
    } else if (!self.firstSample && type == kCMMediaType_Audio) {
        if (self.assetWriterAudioInput.isReadyForMoreMediaData) {
            if (![self.assetWriterAudioInput appendSampleBuffer:sampleBuffer]) {
                NSLog(@"assetWriterAudioInput appendSampleBuffer error");
            }
        }
    }

}

- (void)stopWriting {

    // Listing 8.16
    self.isWriting = NO;
    dispatch_async(self.dispatchQueue, ^{
        [self.assetWriter finishWritingWithCompletionHandler:^{
            if (self.assetWriter.status == AVAssetWriterStatusCompleted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSURL *url = self.assetWriter.outputURL;
                    if ([self.delegate respondsToSelector:@selector(didWriteMovieAtURL:)]) {
                        [self.delegate didWriteMovieAtURL:url];
                    }
                });
            } else {
                NSLog(@"write asset error: %@", self.assetWriter.error);
            }
        }];
    });
    
}

- (NSURL *)outputURL {
    NSString *filePath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:THVideoFilename];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }
    return url;
}

@end
