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
//

#import "THMediaItem.h"

#import "AVMetadataItem+THAdditions.h"
#import "NSFileManager+DirectoryLocations.h"

#define COMMON_META_KEY     @"commonMetadata"
#define AVAILABLE_META_KEY  @"availableMetadataFormats"

@interface THMediaItem ()
@property (strong) NSURL *url;
@property (strong) AVAsset *asset;
@property (strong) THMetadata *metadata;
@property (strong) NSArray *acceptedFormats;
@property BOOL prepared;
@end

@implementation THMediaItem

- (id)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        // Listing 3.3
        _url = url;
        _asset = [AVAsset assetWithURL:url];
        _filename = [url lastPathComponent];
        _filetype = [self fileTypeForURL:url];
        _editable = ![_filetype isEqualToString:AVFileTypeMPEGLayer3];
        _acceptedFormats = @[
                             AVMetadataFormatQuickTimeMetadata,
                             AVMetadataFormatiTunesMetadata,
                             AVMetadataFormatID3Metadata
                             ];
    }
    return self;
}

- (NSString *)fileTypeForURL:(NSURL *)url {

    // Listing 3.3
    NSString *ext = [[url lastPathComponent] pathExtension];
    NSString *type = nil;
    if ([ext isEqualToString:@"m4a"]) {
        type = AVFileTypeAppleM4A;
    } else if ([ext isEqualToString:@"m4v"]) {
        type = AVFileTypeAppleM4V;
    } else if ([ext isEqualToString:@"mov"]) {
        type = AVFileTypeQuickTimeMovie;
    } else {
        type = AVFileTypeMPEGLayer3;
    }
    
    return type;
    
}



- (void)prepareWithCompletionHandler:(THCompletionHandler)completionHandler {
    // Listing 3.4
    if (self.prepared) {
        completionHandler(self.prepared);
        return;
    }
    
    self.metadata = [[THMetadata alloc] init];
    
    [_asset loadValuesAsynchronouslyForKeys:@[COMMON_META_KEY, AVAILABLE_META_KEY] completionHandler:^{
        AVKeyValueStatus commonKeyStatus = [_asset statusOfValueForKey:COMMON_META_KEY  error:nil];
        AVKeyValueStatus availableFormatStatus = [_asset statusOfValueForKey:AVAILABLE_META_KEY error:nil];
        self.prepared = commonKeyStatus == AVKeyValueStatusLoaded && availableFormatStatus == AVKeyValueStatusLoaded;
        if (self.prepared) {
            NSArray *items = _asset.commonMetadata;//公共数据
            for (AVMetadataItem *item in items) {
                [_metadata addMetadataItem:item withKey:item.commonKey];
            }
        }
        
        for (id format in _asset.availableMetadataFormats) {
            if ([_acceptedFormats containsObject:format]) {
                NSArray *items = [_asset metadataForFormat:format];
                for (AVMetadataItem *item in items) {
                    [_metadata addMetadataItem:item withKey:item.keyString];
                }
            }
        }
        
        completionHandler(self.prepared);
    }];
}

- (void)saveWithCompletionHandler:(THCompletionHandler)handler {

    // Listing 3.17
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:self.asset presetName:AVAssetExportPresetPassthrough];
    NSURL *outPutURL = [self tempURL];
    exportSession.outputURL = outPutURL;
    exportSession.outputFileType = self.filetype;
    exportSession.metadata = [self.metadata metadataItems];
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        AVAssetExportSessionStatus status = exportSession.status;
        BOOL success = status == AVAssetExportSessionStatusCompleted;
        if (success) {
            NSFileManager *fileMg = [NSFileManager defaultManager];
            [fileMg removeItemAtURL:self.url error:nil];
            [fileMg moveItemAtURL:outPutURL toURL:self.url error:nil];
            [self reset];
        }
        
        if (handler) {
            handler(success);
        }
    }];
}

- (NSURL *)tempURL {
    NSString *ex = [[self.url lastPathComponent] pathExtension];
    NSString *name = [NSString stringWithFormat:@"temp.%@", ex];
    NSString *tempPath = NSTemporaryDirectory();
    return [NSURL fileURLWithPath: [tempPath stringByAppendingPathComponent:name]];
}

- (void)reset {
    _prepared = NO;
    _asset = [AVAsset assetWithURL:self.url];
}

@end
