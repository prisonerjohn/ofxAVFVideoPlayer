//
//  ofxAVFVideoRenderer.m
//  AVFoundationTest
//
//  Created by Sam Kronick on 5/31/13.
//
//

#import "ofxAVFVideoRenderer.h"
#import <Accelerate/Accelerate.h>

@interface AVFVideoRenderer ()

- (NSDictionary *)pixelBufferAttributes;

@end

@implementation AVFVideoRenderer

@synthesize player = _player;
@synthesize playerItemVideoOutput = _playerItemVideoOutput;
@synthesize playerItem = _playerItem;

//@synthesize playerItem, playerLayer, assetReader, layerRenderer;

@synthesize useTexture = _useTexture;
@synthesize useAlpha = _useAlpha;

@synthesize bLoading = _bLoading;
@synthesize bLoaded = _bLoaded;
@synthesize bAudioLoaded = _bAudioLoaded;
@synthesize bPaused = _bPaused;
@synthesize bMovieDone = _bMovieDone;

@synthesize frameRate = _frameRate;
@synthesize playbackRate = _playbackRate;

#if __MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
@synthesize amplitudes, numAmplitudes;
#endif

int count = 0;

- (id)init
{
    self = [super init];
    if (self) {
        _player = [[AVPlayer alloc] init];
            
        amplitudes = [[NSMutableData data] retain];
        
        _bLoading = NO;
        _bLoaded = NO;
        _bAudioLoaded = NO;
        _bPaused = NO;
        _bMovieDone = NO;
        _bDeallocWhenLoaded = NO;
        
        _frameRate = 0.0;
        _playbackRate = 1.0;
    }
    return self;
}

- (NSDictionary *)pixelBufferAttributes
{
    // kCVPixelFormatType_32ARGB, kCVPixelFormatType_32BGRA, kCVPixelFormatType_422YpCbCr8
    return @{
             (NSString *)kCVPixelBufferOpenGLCompatibilityKey : [NSNumber numberWithBool:self.useTexture],
             (NSString *)kCVPixelBufferPixelFormatTypeKey     : [NSNumber numberWithInt:kCVPixelFormatType_32ARGB]  //[NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8]
            };
}

//--------------------------------------------------------------
- (void)loadFile:(NSString *)filename
{
    _bLoading = YES;
    _bLoaded = NO;
    _bAudioLoaded = NO;
    _bPaused = NO;
    _bMovieDone = NO;
    _bDeallocWhenLoaded = NO;
    
    _frameRate = 0.0;
    _playbackRate = 1.0;
    
    _useTexture = true;
    _useAlpha = false;
    
    //NSURL *fileURL = [NSURL URLWithString:filename];
    NSURL *fileURL = [NSURL fileURLWithPath:[filename stringByStandardizingPath]];
    
    if (amplitudes) {
        [amplitudes setLength:0];
    }
    numAmplitudes = 0;
    
    NSLog(@"Trying to load %@", filename);
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    NSString *tracksKey = @"tracks";
    
    [asset loadValuesAsynchronouslyForKeys:@[tracksKey] completionHandler: ^{
        static const NSString *kItemStatusContext;
        // Perform the following back on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
            // Check to see if the file loaded
            NSError *error;
            AVKeyValueStatus status = [asset statusOfValueForKey:tracksKey error:&error];
            
            if (status == AVKeyValueStatusLoaded) {
                // Asset metadata has been loaded, set up the player.
                
                // Extract the video track to get the video size and other properties.
                AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
                _videoSize = [videoTrack naturalSize];
                _currentTime = kCMTimeZero;
                _duration = asset.duration;
                _frameRate = [videoTrack nominalFrameRate];
                
                self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
                [self.playerItem addObserver:self forKeyPath:@"status" options:0 context:&kItemStatusContext];
                
                // Notify this object when the player reaches the end
                // This allows us to loop the video
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(playerItemDidReachEnd:)
                                                             name:AVPlayerItemDidPlayToEndTimeNotification
                                                           object:self.playerItem];

                [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
                
                // Create and attach video output. 10.8 Only!!!
                _playerItemVideoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:[self pixelBufferAttributes]];
                if (self.playerItemVideoOutput) {
                    self.playerItemVideoOutput.suppressesPlayerRendering = YES;
                }
                [[self.player currentItem] addOutput:self.playerItemVideoOutput];
                
                // Create CVOpenGLTextureCacheRef for optimal CVPixelBufferRef to GL texture conversion.
                if (self.useTexture && !_textureCache) {
                    CVReturn err = CVOpenGLTextureCacheCreate(kCFAllocatorDefault, NULL,
                                                              CGLGetCurrentContext(), CGLGetPixelFormat(CGLGetCurrentContext()),
                                                              NULL, &_textureCache);
                                                              //(CFDictionaryRef)ctxAttributes, &_textureCache);
                    if (err != noErr) {
                        NSLog(@"Error at CVOpenGLTextureCacheCreate %d", err);
//                        return;
                    }
                }
                
                
                
                
//                self.outputDuration = CMTimeGetSeconds([[player currentItem] duration]);
                
//                [self.player play];

                
//                self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
//                
//                self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
//                
//                self.layerRenderer = [CARenderer rendererWithCGLContext:CGLGetCurrentContext() options:nil];
//                self.layerRenderer.layer = playerLayer;
//                
//                // Video is centered on 0,0 for some reason so layer bounds have to start at -width/2,-height/2
//                self.layerRenderer.bounds = CGRectMake(-videoSize.width/2, -videoSize.height/2, videoSize.width, videoSize.height);
//                self.playerLayer.bounds = self.layerRenderer.bounds;



// EZ: Let's worry about this audio stuff later.
//#if __MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
//                NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
//                if ([audioTracks count] > 0) {
//                    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
//
//                    NSError *error = nil;
//                    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
//                    if (error != nil) {
//                        NSLog(@"Unable to create asset reader %@", [error localizedDescription]);
//                    }
//                    else if (audioTrack != nil) {
//                        // Read the audio track data
//                        NSMutableDictionary *bufferOptions = [NSMutableDictionary dictionary];
//                        [bufferOptions setObject:[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
//                        [bufferOptions setObject:@44100 forKey:AVSampleRateKey];
//                        [bufferOptions setObject:@2 forKey:AVNumberOfChannelsKey];
////                        [bufferOptions setObject:[NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)] forKey:AVChannelLayoutKey];
//                        [bufferOptions setObject:@32 forKey:AVLinearPCMBitDepthKey];
//                        [bufferOptions setObject:@NO forKey:AVLinearPCMIsBigEndianKey];
//                        [bufferOptions setObject:@YES forKey:AVLinearPCMIsFloatKey];
//                        [bufferOptions setObject:@NO forKey:AVLinearPCMIsNonInterleaved];
//                        [assetReader addOutput:[AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack
//                                                                                          outputSettings:bufferOptions]];
//                        [assetReader startReading];
//                        
//                        count = 0;
//                    
//                        // Add a periodic time observer that will store the audio track data in a buffer that we can access later
//                        periodicTimeObserver = [player addPeriodicTimeObserverForInterval:CMTimeMake(1001, [audioTrack nominalFrameRate] * 1001)
//                                                                                    queue:dispatch_queue_create("eventQueue", NULL)
//                                                                               usingBlock:^(CMTime time) {
//                                                                                   if ([assetReader status] == AVAssetReaderStatusCompleted) {
//                                                                                       // Got all the data we need, kill this block.
//                                                                                       [player removeTimeObserver:periodicTimeObserver];
//                                                                                       
//                                                                                       numAmplitudes = [amplitudes length] / sizeof(float);
//                                                                                       audioReady = YES;
//                                                                                       
//                                                                                       return;
//                                                                                   }
//                                                                                   
//                                                                                   if ([assetReader status] == AVAssetReaderStatusReading) {
//                                                                                       AVAssetReaderTrackOutput *output = [[assetReader outputs] objectAtIndex:0];
//                                                                                       CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
//                                                                                       
//                                                                                       while (sampleBuffer != NULL) {
//                                                                                           sampleBuffer = [output copyNextSampleBuffer];
//                                                                                           
//                                                                                           if (sampleBuffer == NULL)
//                                                                                               continue;
//                                                                                           
//                                                                                           CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(sampleBuffer);
//                                                                                           
//                                                                                           size_t lengthAtOffset;
//                                                                                           size_t totalLength;
//                                                                                           char* data;
//                                                                                           
//                                                                                           if (CMBlockBufferGetDataPointer(buffer, 0, &lengthAtOffset, &totalLength, &data) != noErr) {
//                                                                                               NSLog(@"error!");
//                                                                                               break;
//                                                                                           }
//                                                                                           
//                                                                                           CMItemCount numSamplesInBuffer = CMSampleBufferGetNumSamples(sampleBuffer);
//                                                                                           
//                                                                                           AudioBufferList audioBufferList;
//                                                                                           
//                                                                                           CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
//                                                                                                                                                   NULL,
//                                                                                                                                                   &audioBufferList,
//                                                                                                                                                   sizeof(audioBufferList),
//                                                                                                                                                   NULL,
//                                                                                                                                                   NULL,
//                                                                                                                                                   kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,  // pass in something else
//                                                                                                                                                   &buffer);
//                                                                                           
//                                                                                           for (int bufferCount = 0; bufferCount < audioBufferList.mNumberBuffers; bufferCount++) {
//                                                                                               [amplitudes appendBytes:audioBufferList.mBuffers[bufferCount].mData
//                                                                                                                length:audioBufferList.mBuffers[bufferCount].mDataByteSize];
//                                                                                           }
//                                                                                                                                                                                      
//                                                                                           CFRelease(buffer);
//                                                                                           CFRelease(sampleBuffer);
//                                                                                       }
//                                                                                   }
//                                                                               }];
//                    }
//                }
//#endif
                _bLoading = NO;
                _bLoaded = YES;
            }
            else {
                _bLoading = NO;
                _bLoaded = NO;
                NSLog(@"There was an error loading the file: %@", error);
            }
            
            // If dealloc is called immediately after loadFile, we have to defer releasing properties.
            if (_bDeallocWhenLoaded) [self dealloc];
            
            [pool release];
        });
    }];
}

//--------------------------------------------------------------
- (void)dealloc
{
    if (_bLoading) {
        _bDeallocWhenLoaded = YES;
    }
    else {
        [self stop];
        
        // SK: Releasing the CARenderer is slow for some reason
        //     It will freeze the main thread for a few dozen mS.
        //     If you're swapping in and out videos a lot, the loadFile:
        //     method should be re-written to just re-use and re-size
        //     these layers/objects rather than releasing and reallocating
        //     them every time a new file is needed.
        
//        if(self.layerRenderer) [self.layerRenderer release];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        if (self.playerItem) {
            [self.playerItem removeObserver:self forKeyPath:@"status"];
            [self.playerItem release];
        }
                
//        [_player release];  // No need
        _player = nil;
        
        [_playerItemVideoOutput release];
        _playerItemVideoOutput = nil;
        
        if (_textureCache != NULL) {
			CVOpenGLTextureCacheRelease(_textureCache);
			_textureCache = NULL;
		}
        if (_latestTextureFrame != NULL) {
			CVOpenGLTextureRelease(_latestTextureFrame);
			_latestTextureFrame = NULL;
		}
		if (_latestPixelFrame != NULL) {
			CVPixelBufferRelease(_latestPixelFrame);
			_latestPixelFrame = NULL;
		}
        
        if (amplitudes) [amplitudes release];
        numAmplitudes = 0;
        
        if (!_bDeallocWhenLoaded) [super dealloc];
    }
}

//--------------------------------------------------------------
- (void)play
{
    [self.player play];
    [self.player setRate:_playbackRate];
}

//--------------------------------------------------------------
- (void)stop
{
    // Pause and rewind.
    [self.player pause];
    [self.player seekToTime:kCMTimeZero];
}

//--------------------------------------------------------------
- (void)setPaused:(BOOL)bPaused
{
    _bPaused = bPaused;
    if (_bPaused) {
        [self.player pause];
    }
    else {
        [self.player play];
        [self.player setRate:_playbackRate];
    }
}

//--------------------------------------------------------------
- (BOOL)isPlaying
{
    if (![self isLoaded])
        return false;
    
	return ![self isMovieDone] && ![self isPaused];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
}

//--------------------------------------------------------------
- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    _bMovieDone = YES;
    
    // if(loop)
    //[self.player play];
}

//--------------------------------------------------------------
- (BOOL)update
{
//    CMTime outputItemTime = kCMTimeInvalid;
//	
//	// Calculate the nextVsync time which is when the screen will be refreshed next.
//	CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);
//	
//	outputItemTime = [[self videoOutput] itemTimeForHostTime:nextVSync];
//	
//	if ([[self videoOutput] hasNewPixelBufferForItemTime:outputItemTime]) {
//		CVPixelBufferRef pixelBuffer = NULL;
//		pixelBuffer = [[self videoOutput] copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
//		
//		[[self playerView] displayPixelBuffer:pixelBuffer];
//	}
    
    
    // Check our video output for new frames.
    CMTime outputItemTime = [self.playerItemVideoOutput itemTimeForHostTime:CACurrentMediaTime()];
    if ([self.playerItemVideoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
        // Get pixels.
        if (_latestPixelFrame != NULL) {
            CVPixelBufferRelease(_latestPixelFrame);
            _latestPixelFrame = NULL;
        }
        _latestPixelFrame = [self.playerItemVideoOutput copyPixelBufferForItemTime:outputItemTime
                                                                itemTimeForDisplay:NULL];
        
        if (self.useTexture) {
            // Create GL texture.
            if (_latestTextureFrame != NULL) {
                CVOpenGLTextureRelease(_latestTextureFrame);
                _latestTextureFrame = NULL;
                CVOpenGLTextureCacheFlush(_textureCache, 0);
            }
            
            CVReturn err = CVOpenGLTextureCacheCreateTextureFromImage(NULL, _textureCache, _latestPixelFrame, NULL, &_latestTextureFrame);
            if (err != noErr) {
                NSLog(@"Error creating OpenGL texture %d", err);
            }
        }
                
        // Update time.
        _currentTime = [[self.player currentItem] currentTime];
        _duration = [[self.player currentItem] duration];
//        [self.player getCurrentFrame
        
//        self.outputMovieTime = currentTime;
//        self.outputPlayheadPosition = currentTime / duration;
        
//        NSLog(@"Curr time is %f, curr playhead is %f", self.outputMovieTime, self.outputPlayheadPosition);
        
        return YES;
    }
    
    return NO;
}

//- (void) render {
//    // From https://qt.gitorious.org/qt/qtmultimedia/blobs/700b4cdf42335ad02ff308cddbfc37b8d49a1e71/src/plugins/avfoundation/mediaplayer/avfvideoframerenderer.mm
//    
//    glPushAttrib(GL_ENABLE_BIT);
//    glDisable(GL_DEPTH_TEST);
//    
//    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
//    glClear(GL_COLOR_BUFFER_BIT);
//    
//    glViewport(0, 0, _videoSize.width, _videoSize.height);
//    
//    glMatrixMode(GL_PROJECTION);
//    glPushMatrix();
//    glLoadIdentity();
//    
//    glOrtho(0.0f, videoSize.width, videoSize.height, 0.0f, 0.0f, 1.0f);
//    
//    glMatrixMode(GL_MODELVIEW);
//    glPushMatrix();
//    glLoadIdentity();
//    
//    glTranslatef(videoSize.width/2,videoSize.height/2,0);
//    
//    [layerRenderer beginFrameAtTime:CACurrentMediaTime() timeStamp:NULL];
//    [layerRenderer addUpdateRect:layerRenderer.layer.bounds];
//    [layerRenderer render];
//    [layerRenderer endFrame];
//    
//    glMatrixMode(GL_MODELVIEW);
//    glPopMatrix();
//    glMatrixMode(GL_PROJECTION);
//    glPopMatrix();
//    
//    glPopAttrib();
//    
//    glFinish(); //Rendering needs to be done before passing texture to video frame
//}

#pragma mark - Pixels and Texture

//--------------------------------------------------------------
- (double)width
{
    return _videoSize.width;
}

//--------------------------------------------------------------
- (double)height
{
    return _videoSize.height;
}

//--------------------------------------------------------------
- (void)pixels:(unsigned char *)outbuf
{
    if (_latestPixelFrame == NULL) return;
		
//    NSLog(@"pixel buffer width is %ld height %ld and bpr %ld, movie size is %d x %d ",
//      CVPixelBufferGetWidth(_latestPixelFrame),
//      CVPixelBufferGetHeight(_latestPixelFrame),
//      CVPixelBufferGetBytesPerRow(_latestPixelFrame),
//      (NSInteger)movieSize.width, (NSInteger)movieSize.height);
    if ((NSInteger)self.width != CVPixelBufferGetWidth(_latestPixelFrame) || (NSInteger)self.height != CVPixelBufferGetHeight(_latestPixelFrame)) {
        NSLog(@"CoreVideo pixel buffer is %ld x %ld while self reports size of %d x %d. This is most likely caused by a non-square pixel video format such as HDV. Open this video in texture only mode to view it at the appropriate size",
              CVPixelBufferGetWidth(_latestPixelFrame), CVPixelBufferGetHeight(_latestPixelFrame), (NSInteger)self.width, (NSInteger)self.height);
        return;
    }
    
    if (CVPixelBufferGetPixelFormatType(_latestPixelFrame) != kCVPixelFormatType_32ARGB) {
        NSLog(@"QTKitMovieRenderer - Frame pixelformat not kCVPixelFormatType_32ARGB: %d, instead %ld", kCVPixelFormatType_32ARGB, CVPixelBufferGetPixelFormatType(_latestPixelFrame));
        return;
    }
    
    CVPixelBufferLockBaseAddress(_latestPixelFrame, kCVPixelBufferLock_ReadOnly);
    //If we are using alpha, the ofxAVFVideoPlayer class will have allocated a buffer of size
    //video.width * video.height * 4
    //CoreVideo creates alpha video in the format ARGB, and openFrameworks expects RGBA,
    //so we need to swap the alpha around using a vImage permutation
    vImage_Buffer src = {
        CVPixelBufferGetBaseAddress(_latestPixelFrame),
        CVPixelBufferGetHeight(_latestPixelFrame),
        CVPixelBufferGetWidth(_latestPixelFrame),
        CVPixelBufferGetBytesPerRow(_latestPixelFrame)
    };
    vImage_Error err;
    if (self.useAlpha) {
        vImage_Buffer dest = { outbuf, self.height, self.width, self.width * 4 };
        uint8_t permuteMap[4] = { 1, 2, 3, 0 }; //swizzle the alpha around to the end to make ARGB -> RGBA
        err = vImagePermuteChannels_ARGB8888(&src, &dest, permuteMap, 0);
    }
    //If we are are doing RGB then ofxAVFVideoPlayer will have created a buffer of size video.width * video.height * 3
    //so we use vImage to copy them into the out buffer
    else {
        vImage_Buffer dest = { outbuf, self.height, self.width, self.width * 3 };
        err = vImageConvert_ARGB8888toRGB888(&src, &dest, 0);
    }
    
    CVPixelBufferUnlockBaseAddress(_latestPixelFrame, kCVPixelBufferLock_ReadOnly);
    
    if (err != kvImageNoError) {
        NSLog(@"Error in Pixel Copy vImage_error %ld", err);
    }
}

//--------------------------------------------------------------
- (BOOL)textureAllocated
{
	return self.useTexture && _latestTextureFrame != NULL;
}

//--------------------------------------------------------------
- (GLuint)textureID
{
	@synchronized(self) {
		return CVOpenGLTextureGetName(_latestTextureFrame);
	}
}

//--------------------------------------------------------------
- (GLenum)textureTarget
{
    return CVOpenGLTextureGetTarget(_latestTextureFrame);
}

//--------------------------------------------------------------
- (void)bindTexture
{
	if (!self.textureAllocated) return;
    
	GLuint texID = [self textureID];
	GLenum target = [self textureTarget];
	
	glEnable(target);
	glBindTexture(target, texID);
}

//--------------------------------------------------------------
- (void) unbindTexture
{
	if (!self.textureAllocated) return;
	
	GLenum target = [self textureTarget];
	glDisable(target);
}

#pragma mark - Playhead

//--------------------------------------------------------------
- (double)duration
{
    return CMTimeGetSeconds(_duration);
}

//--------------------------------------------------------------
- (int)totalFrames
{
    return self.duration * self.frameRate;
}

//--------------------------------------------------------------
- (double)currentTime
{
    return CMTimeGetSeconds(_currentTime);
}

//--------------------------------------------------------------
- (void)setCurrentTime:(double)currentTime
{
    [self.player seekToTime:CMTimeMakeWithSeconds(currentTime, _duration.timescale)];
}

//--------------------------------------------------------------
- (int)currentFrame
{
    return self.currentTime * self.frameRate;
}

//--------------------------------------------------------------
- (void)setCurrentFrame:(int)currentFrame
{
    float position = currentFrame / (float)self.totalFrames;
    [self setPosition:position];
}

//--------------------------------------------------------------
- (double)position
{
    return self.currentTime / self.duration;
}

//--------------------------------------------------------------
- (void)setPosition:(double)position
{
    double time = self.duration * position;
    //    [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
    [self.player seekToTime:CMTimeMakeWithSeconds(time, _duration.timescale)];
}

//--------------------------------------------------------------
- (void)setPlaybackRate:(double)playbackRate
{
    _playbackRate = playbackRate;
    [self.player setRate:_playbackRate];
}

@end
