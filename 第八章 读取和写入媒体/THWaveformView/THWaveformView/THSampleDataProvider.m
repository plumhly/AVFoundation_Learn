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

#import "THSampleDataProvider.h"

@implementation THSampleDataProvider

+ (void)loadAudioSamplesFromAsset:(AVAsset *)asset
                  completionBlock:(THSampleDataCompletionBlock)completionBlock {
    
    // Listing 8.2
    NSString *trackKey = @"tracks";
    [asset loadValuesAsynchronouslyForKeys:@[trackKey] completionHandler:^{
        AVKeyValueStatus status = [asset statusOfValueForKey:trackKey error:nil];
        NSData *data = nil;
        if (status != AVKeyValueStatusLoaded) {
            NSLog(@"trackKey status error");
        } else {
            data = [self readAudioSamplesFromAsset:asset];
        }
        if (completionBlock) {
            completionBlock(data);
        }
    }];

}

+ (NSData *)readAudioSamplesFromAsset:(AVAsset *)asset {

    // Listing 8.3
    
    // reader
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    NSDictionary *settings = @{
                               AVFormatIDKey:@(kAudioFormatLinearPCM),
                               AVLinearPCMIsFloatKey: @(NO),
                               AVLinearPCMIsBigEndianKey: @(NO),
                               AVLinearPCMBitDepthKey: @(16)
                               };
    AVAssetReaderTrackOutput *trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
    
    NSError *error = nil;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error: &error];
    if (error) {
        NSLog(@"create AVAssetReader faild with error: %@", error.localizedDescription);
    }
    [assetReader addOutput:trackOutput];
    [assetReader startReading];

    NSMutableData *data = [NSMutableData data];
    while (assetReader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sampleBuffer = trackOutput.copyNextSampleBuffer;
        if (sampleBuffer) {
            CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
            size_t length = CMBlockBufferGetDataLength(blockBuffer);
            SInt16 buffer[length];
            OSStatus sts = CMBlockBufferCopyDataBytes(blockBuffer, 0, length, buffer);
            if (sts == kCMBlockBufferNoErr) {
                [data appendBytes:buffer length:length];
            }
            CMSampleBufferInvalidate(sampleBuffer);
            CFRelease(sampleBuffer);
        }
    }
    
    if (assetReader.status == AVAssetReaderStatusCompleted) {
        return data;
    } else {
        NSLog(@"fail to read audio samples from asset");
        return nil;
    }
}

@end
