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

#import "THCameraController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "NSFileManager+THAdditions.h"

NSString *const THThumbnailCreatedNotification = @"THThumbnailCreated";
static const NSString *THCameraAdjustingExposureContext;

@interface THCameraController () <AVCaptureFileOutputRecordingDelegate>

@property (strong, nonatomic) dispatch_queue_t videoQueue;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (weak, nonatomic) AVCaptureDeviceInput *activeVideoInput;
@property (strong, nonatomic) AVCaptureStillImageOutput *imageOutput;
@property (strong, nonatomic) AVCaptureMovieFileOutput *movieOutput;
@property (strong, nonatomic) NSURL *outputURL;

@end

@implementation THCameraController

- (BOOL)setupSession:(NSError **)error {

    // Listing 6.4
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
    
    if (videoDeviceInput) {
        if ([_captureSession canAddInput:videoDeviceInput]) {
            [_captureSession addInput:videoDeviceInput];
            _activeVideoInput = videoDeviceInput;
        }
    } else {
        return NO;
    }
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
    if (audioDevice) {
        if ([_captureSession canAddInput:audioDeviceInput]) {
            [_captureSession addInput:audioDeviceInput];
        }
    } else {
        return NO;
    }
    
    
    _imageOutput = [[AVCaptureStillImageOutput alloc] init];
    _imageOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
//    _imageOutput = [];
    if ([_captureSession canAddOutput:_imageOutput]) {
        [_captureSession addOutput:_imageOutput];
    }
    
    _movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([_captureSession canAddOutput:_movieOutput]) {
        [_captureSession addOutput:_movieOutput];
    }
    _videoQueue = dispatch_queue_create("com.tapharmonic.VideoQueue", NULL);
    return YES;
}

- (void)startSession {

    // Listing 6.5
    if (![_captureSession isRunning]) {
        dispatch_async(_videoQueue, ^{
            [_captureSession startRunning];
        });
    }
    
}

- (void)stopSession {

    // Listing 6.5
    if ([_captureSession isRunning]) {
        dispatch_async(_videoQueue, ^{
            [_captureSession stopRunning];
        });
    }

}

#pragma mark - Device Configuration

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {

    // Listing 6.6
    AVCaptureDevice *tempDevice = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            tempDevice = device;
        }
    }
    
    return tempDevice;
}

- (AVCaptureDevice *)activeCamera {

    // Listing 6.6
    return _activeVideoInput.device;
}

- (AVCaptureDevice *)inactiveCamera {

    // Listing 6.6
    AVCaptureDevice *tempDevice = nil;
    if (self.cameraCount > 1) {
        if ([self activeCamera].position == AVCaptureDevicePositionBack) {
            tempDevice = [self cameraWithPosition: AVCaptureDevicePositionFront];
        } else {
             tempDevice = [self cameraWithPosition: AVCaptureDevicePositionBack];
        }
    }

    return tempDevice;
}

- (BOOL)canSwitchCameras {

    // Listing 6.6
    
    return self.cameraCount > 1;
}

- (NSUInteger)cameraCount {

    // Listing 6.6
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count;
}

- (BOOL)switchCameras {

    // Listing 6.7
    if (![self canSwitchCameras]) {
        return NO;
    }
    
    NSError *error = nil;
    AVCaptureDevice *device = [self inactiveCamera];
    AVCaptureDeviceInput *deviceInpute = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (deviceInpute) {
        [_captureSession beginConfiguration];
        [_captureSession removeInput:_activeVideoInput];
        if ([_captureSession canAddInput:deviceInpute]) {
            [_captureSession addInput:deviceInpute];
            _activeVideoInput = deviceInpute;
        } else {
             [_captureSession addInput:_activeVideoInput];
        }
        [_captureSession commitConfiguration];
    } else {
        [self.delegate deviceConfigurationFailedWithError:error];
        return NO;
    }
    
    return YES;
}

#pragma mark - Focus Methods

- (BOOL)cameraSupportsTapToFocus {
    
    // Listing 6.8
    
    return [[self activeCamera] isFocusPointOfInterestSupported];
}

- (void)focusAtPoint:(CGPoint)point {
    
    // Listing 6.8
    AVCaptureDevice *device = [self activeCamera];
    if (self.cameraSupportsTapToFocus && [device isFocusModeSupported: AVCaptureFocusModeAutoFocus]) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        } else {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
    
}

#pragma mark - Exposure Methods

- (BOOL)cameraSupportsTapToExpose {
 
    // Listing 6.9
    
    return [self activeCamera].isExposurePointOfInterestSupported;
}

- (void)exposeAtPoint:(CGPoint)point {

    // Listing 6.9
    if ([self cameraSupportsTapToExpose]) {
        AVCaptureDevice *camera = [self activeCamera];
        AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
//        AVCaptureExposureMode exposureMode = AVCaptureExposureModeAutoExpose;
        if ([camera isExposureModeSupported:exposureMode]) {
            NSError *error = nil;
            if ([camera lockForConfiguration:&error]) {
                camera.exposurePointOfInterest = point;
                camera.exposureMode = exposureMode;
                if ([camera isExposureModeSupported:AVCaptureExposureModeLocked]) {
                    [camera addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:&THCameraAdjustingExposureContext];
                }
                [camera unlockForConfiguration];
            } else {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
    }

}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    // Listing 6.9
    if (context == &THCameraAdjustingExposureContext) {
        AVCaptureDevice *camera = (AVCaptureDevice *)object;
        if (!camera.isAdjustingExposure) {
            [camera removeObserver:self forKeyPath:@"adjustingExposure" context:&THCameraAdjustingExposureContext];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = nil;
                if ([camera lockForConfiguration:&error]) {
                    camera.exposureMode = AVCaptureExposureModeLocked;
                    [camera unlockForConfiguration];
                } else {
                    [self.delegate deviceConfigurationFailedWithError:error];
                }
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }

}

- (void)resetFocusAndExposureModes {

    // Listing 6.10

    AVCaptureDevice *device = [self activeCamera];
    
    AVCaptureFocusMode focusMode = AVCaptureFocusModeContinuousAutoFocus;
    BOOL focusReset = device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode];
    
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    BOOL exposureReset = device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode];
    
    CGPoint center = CGPointMake(0.5, 0.5);
    
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        if (focusReset) {
            device.focusPointOfInterest = center;
            device.focusMode = focusMode;
        }
        
        if (exposureReset) {
            device.exposurePointOfInterest = center;
            device.exposureMode = exposureMode;
        }
        [device unlockForConfiguration];
    } else {
        [self.delegate deviceConfigurationFailedWithError:error];
    }
}



#pragma mark - Flash and Torch Modes

- (BOOL)cameraHasFlash {

    // Listing 6.11
    
    return [self activeCamera].hasFlash;
}

- (AVCaptureFlashMode)flashMode {

    // Listing 6.11
    
    return [[self activeCamera] flashMode];
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode {

    // Listing 6.11
    AVCaptureDevice *device = [self activeCamera];
    if ([device isFlashModeSupported:flashMode]) {
        NSError *error = nil;
        if ([device lockForConfiguration: &error]) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        } else {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

- (BOOL)cameraHasTorch {

    // Listing 6.11
    
    return [self activeCamera].hasTorch;
}

- (AVCaptureTorchMode)torchMode {

    // Listing 6.11
    
    return [[self activeCamera] torchMode];
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode {

    // Listing 6.11
    AVCaptureDevice *device = [self activeCamera];
    if ([device isTorchModeSupported:torchMode]) {
        NSError *error = nil;
        if ([device lockForConfiguration: &error]) {
            device.torchMode = torchMode;
            [device unlockForConfiguration];
        } else {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}


#pragma mark - Image Capture Methods

- (void)captureStillImage {

    // Listing 6.12
    AVCaptureConnection *connetion = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connetion.isVideoOrientationSupported) {
        connetion.videoOrientation = [self currentVideoOrientation];
    }
    
    [_imageOutput captureStillImageAsynchronouslyFromConnection:connetion completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
        if (imageDataSampleBuffer != NULL) {
            NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:data];
            [self writeImageToAssetsLibrary:image];
        } else {
            NSLog(@"%@", [error localizedDescription]);
        }
       
    }];
}

- (AVCaptureVideoOrientation)currentVideoOrientation {
    
    // Listing 6.12
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    AVCaptureVideoOrientation or;
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            or = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationLandscapeLeft:
            or = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            or = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
            
        default:
            or = AVCaptureVideoOrientationLandscapeLeft;
            break;
    }
    
    // Listing 6.13
    
    return or;
}


- (void)writeImageToAssetsLibrary:(UIImage *)image {

    // Listing 6.13
    ALAssetsLibrary *library = [ALAssetsLibrary new];
    [library writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error) {
        if (!error) {
            [self postThumbnailNotifification:image];
        } else {
            NSLog(@"%@", error.localizedDescription);
        }
    }];
    
}

- (void)postThumbnailNotifification:(UIImage *)image {

    // Listing 6.13
    [[NSNotificationCenter defaultCenter] postNotificationName:THThumbnailCreatedNotification object:image];
}

#pragma mark - Video Capture Methods

- (BOOL)isRecording {

    // Listing 6.14
    
    return [self.movieOutput isRecording];
}

- (void)startRecording {

    // Listing 6.14
    if (![self isRecording]) {
        AVCaptureConnection *videoConnection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
        if (videoConnection.isVideoOrientationSupported) {
            videoConnection.videoOrientation = [self currentVideoOrientation];
        }
    
        if ([videoConnection isVideoStabilizationSupported]) {
            [videoConnection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeAuto];
        }
        
        AVCaptureDevice *device = [self activeCamera];
        if (device.isSmoothAutoFocusSupported) {
            NSError *error = nil;
            if ([device lockForConfiguration:&error]) {
                device.smoothAutoFocusEnabled = YES;
                [device unlockForConfiguration];
            } else {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
        self.outputURL = [self uniqueURL];
        [_movieOutput startRecordingToOutputFileURL:_outputURL recordingDelegate:self];
    }

}

- (CMTime)recordedDuration {
    return self.movieOutput.recordedDuration;
}

- (NSURL *)uniqueURL {


    // Listing 6.14
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [fileManager temporaryDirectoryWithTemplateString:@"kamera.XXXXXX"];
    if (path) {
        path = [path stringByAppendingPathComponent:@"kamera.mov"];
        return [NSURL fileURLWithPath:path];
    }
    return nil;
}

- (void)stopRecording {

    // Listing 6.14
    if ([self isRecording]) {
        [self.movieOutput stopRecording];
    }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray *)connections
                error:(NSError *)error {

    // Listing 6.15
    if (error) {
        [self.delegate mediaCaptureFailedWithError:error];
    } else {
        [self writeVideoToAssetsLibrary:[self.outputURL copy]];
    }
    _outputURL = nil;
}

- (void)writeVideoToAssetsLibrary:(NSURL *)videoURL {

    // Listing 6.15
    ALAssetsLibrary *library = [ALAssetsLibrary new];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:videoURL]) {
        [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
            if (error) {
                [self.delegate assetLibraryWriteFailedWithError:error];
            } else {
                [self generateThumbnailForVideoAtURL:videoURL];
            }
        }];
    }
    
}

- (void)generateThumbnailForVideoAtURL:(NSURL *)videoURL {

    // Listing 6.15
    dispatch_async(self.videoQueue, ^{
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        imageGenerator.maximumSize = CGSizeMake(100, 0);
        imageGenerator.appliesPreferredTrackTransform = YES;
        CGImageRef imageRef = [imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:NULL error: nil];
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self postThumbnailNotifification:image];
        });
    });
    
    
}


@end

