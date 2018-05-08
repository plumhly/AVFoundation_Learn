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

#import "AVCaptureDevice+THAdditions.h"
#import "THError.h"

@interface THQualityOfService : NSObject

// Listing 7.23
@property (nonatomic, strong, readonly) AVCaptureDeviceFormat *formate;
@property (nonatomic, strong, readonly) AVFrameRateRange *frameRateRange;
@property (nonatomic, assign, readonly, getter=isHightFrameRate) BOOL HightFrameRate;


+ (instancetype)qosWithFormate:(AVCaptureDeviceFormat *)formate frameRateRange:(AVFrameRateRange *)frameRange;

- (BOOL)isHightFrameRate;

@end

@implementation THQualityOfService

// Listing 7.23

+ (instancetype)qosWithFormate:(AVCaptureDeviceFormat *)formate frameRateRange:(AVFrameRateRange *)frameRange {
    return [[[self class] alloc] initWithFormate:formate frameRateRange:frameRange];
}

- (instancetype)initWithFormate:(AVCaptureDeviceFormat *)formate frameRateRange:(AVFrameRateRange *)frameRange {
    if (self = [super init]) {
        _formate = formate;
        _frameRateRange = frameRange;
    }
    return self;
}

- (BOOL)isHightFrameRate {
    return _frameRateRange.maxFrameRate > 30.f;
}

@end

@implementation AVCaptureDevice (THAdditions)

- (BOOL)supportsHighFrameRateCapture {

    // Listing 7.24
    if (![self hasMediaType:AVMediaTypeVideo]) {
        return NO;
    }

    return [self findHighestQualityOfService].isHightFrameRate;
}

- (THQualityOfService *)findHighestQualityOfService {

    // Listing 7.24
    AVCaptureDeviceFormat *maxFormat = nil;
    AVFrameRateRange *maxRateRange = nil;
    for (AVCaptureDeviceFormat *format in self.formats) {
        FourCharCode formatCode = CMVideoFormatDescriptionGetCodecType(format.formatDescription);
        if (formatCode == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
                if (range.maxFrameRate > maxRateRange.maxFrameRate) {
                    maxFormat = format;
                    maxRateRange = range;
                }
            }
        }
    }

    return [THQualityOfService qosWithFormate:maxFormat frameRateRange:maxRateRange];
}

- (BOOL)enableMaxFrameRateCapture:(NSError **)error {

    // Listing 7.25
    if (![self supportsHighFrameRateCapture]) {
        NSDictionary *userinfo = @{NSLocalizedDescriptionKey: @"device not support high frame rate range capture"};
        *error = [NSError errorWithDomain:THCameraErrorDomain code:THCameraErrorHighFrameRateCaptureNotSupported userInfo:userinfo];
        return NO;
    }
    
    THQualityOfService *service = [self findHighestQualityOfService];
    
    if ([self lockForConfiguration:error]) {
        CMTime duration = service.frameRateRange.minFrameDuration;
        self.activeFormat = service.formate;
        self.activeVideoMinFrameDuration = duration;
        self.activeVideoMaxFrameDuration = duration;
        [self unlockForConfiguration];
        return YES;
    }

    return NO;
}

@end
