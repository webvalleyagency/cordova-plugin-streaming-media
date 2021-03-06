#import "StreamingMedia.h"
#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "LandscapeVideo.h"
#import "PortraitVideo.h"

@interface StreamingMedia()
- (void)parseOptions:(NSDictionary *) options type:(NSString *) type;
- (void)play:(CDVInvokedUrlCommand *) command type:(NSString *) type;
- (void)setBackgroundColor:(NSString *)color;
- (void)setImage:(NSString*)imagePath withScaleType:(NSString*)imageScaleType;
- (UIImage*)getImage: (NSString *)imageName;
- (void)startPlayer:(NSString*)uri;
- (void)moviePlayBackDidFinish:(NSNotification*)notification;
- (void)cleanup;
@end

@implementation StreamingMedia {
    NSString* callbackId;
    AVPlayerViewController *moviePlayer;
    BOOL shouldAutoClose;
    UIColor *backgroundColor;
    UIImageView *imageView;
    BOOL initFullscreen;
    NSString *mOrientation;
    NSString *videoType;
    AVPlayer *movie;
    NSInteger controls;
    NSNumber *startTimeInMs;
    UIButton *playPauseButton;
    UIButton *closeButton;
    BOOL overlayShown;
}

NSString * const TYPE_VIDEO = @"VIDEO";
NSString * const TYPE_AUDIO = @"AUDIO";
NSString * const DEFAULT_IMAGE_SCALE = @"center";

-(void)parseOptions:(NSDictionary *)options type:(NSString *) type {
    // Common options
    mOrientation = options[@"orientation"] ?: @"default";

    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"shouldAutoClose"]) {
        shouldAutoClose = [[options objectForKey:@"shouldAutoClose"] boolValue];
    } else {
        shouldAutoClose = YES;
    }
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgColor"]) {
        [self setBackgroundColor:[options objectForKey:@"bgColor"]];
    } else {
        backgroundColor = [UIColor blackColor];
    }

    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"initFullscreen"]) {
        initFullscreen = [[options objectForKey:@"initFullscreen"] boolValue];
    } else {
        initFullscreen = YES;
    }

    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"controls"]) {
        controls = [[options objectForKey:@"controls"] integerValue];
    } else {
        controls = 2;
    }

    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"startTimeInMs"]) {
        startTimeInMs = [options objectForKey:@"startTimeInMs"];
    } else {
        startTimeInMs = @0;
    }

    if ([type isEqualToString:TYPE_AUDIO]) {
        videoType = TYPE_AUDIO;

        // bgImage
        // bgImageScale
        if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgImage"]) {
            NSString *imageScale = DEFAULT_IMAGE_SCALE;
            if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgImageScale"]) {
                imageScale = [options objectForKey:@"bgImageScale"];
            }
            [self setImage:[options objectForKey:@"bgImage"] withScaleType:imageScale];
        }
        // bgColor
        if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"bgColor"]) {
            NSLog(@"Found option for bgColor");
            [self setBackgroundColor:[options objectForKey:@"bgColor"]];
        } else {
            backgroundColor = [UIColor blackColor];
        }
    } else {
        // Reset overlay on video player after playing audio
        [self cleanup];
    }
    // No specific options for video yet
}

-(void)play:(CDVInvokedUrlCommand *) command type:(NSString *) type {
    NSLog(@"play called");
    callbackId = command.callbackId;
    NSString *mediaUrl  = [command.arguments objectAtIndex:0];
    [self parseOptions:[command.arguments objectAtIndex:1] type:type];

    [self startPlayer:mediaUrl];
}

-(void)stop:(CDVInvokedUrlCommand *) command type:(NSString *) type {
    NSLog(@"stop called");
    callbackId = command.callbackId;
    if (moviePlayer.player) {
        [moviePlayer.player pause];
    }
}

-(void)playVideo:(CDVInvokedUrlCommand *) command {
    NSLog(@"playvideo called");
    [self ignoreMute];
    [self play:command type:[NSString stringWithString:TYPE_VIDEO]];
}

-(void)playAudio:(CDVInvokedUrlCommand *) command {
    NSLog(@"playaudio called");
    [self ignoreMute];
    [self play:command type:[NSString stringWithString:TYPE_AUDIO]];
}

-(void)stopAudio:(CDVInvokedUrlCommand *) command {
    [self stop:command type:[NSString stringWithString:TYPE_AUDIO]];
}

// Ignore the mute button
-(void)ignoreMute {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
}

-(void) setBackgroundColor:(NSString *)color {
    NSLog(@"setbackgroundcolor called");
    if ([color hasPrefix:@"#"]) {
        // HEX value
        unsigned rgbValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:color];
        [scanner setScanLocation:1]; // bypass '#' character
        [scanner scanHexInt:&rgbValue];
        backgroundColor = [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];
    } else {
        // Color name
        NSString *selectorString = [[color lowercaseString] stringByAppendingString:@"Color"];
        SEL selector = NSSelectorFromString(selectorString);
        UIColor *colorObj = [UIColor blackColor];
        if ([UIColor respondsToSelector:selector]) {
            colorObj = [UIColor performSelector:selector];
        }
        backgroundColor = colorObj;
    }
}

-(UIImage*)getImage: (NSString *)imageName {
    NSLog(@"getimage called");
    UIImage *image = nil;
    if (imageName != (id)[NSNull null]) {
        if ([imageName hasPrefix:@"http"]) {
            // Web image
            image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:imageName]]];
        } else if ([imageName hasPrefix:@"www/"]) {
            // Asset image
            image = [UIImage imageNamed:imageName];
        } else if ([imageName hasPrefix:@"file://"]) {
            // Stored image
            image = [UIImage imageWithData:[NSData dataWithContentsOfFile:[[NSURL URLWithString:imageName] path]]];
        } else if ([imageName hasPrefix:@"data:"]) {
            // base64 encoded string
            NSURL *imageURL = [NSURL URLWithString:imageName];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            image = [UIImage imageWithData:imageData];
        } else {
            // explicit path
            image = [UIImage imageWithData:[NSData dataWithContentsOfFile:imageName]];
        }
    }
    return image;
}

- (void)orientationChanged:(NSNotification *)notification {
    NSLog(@"orientationchanged called");
    if (imageView != nil) {
        // adjust imageView for rotation
        imageView.bounds = moviePlayer.contentOverlayView.bounds;
        imageView.frame = moviePlayer.contentOverlayView.frame;
    }
}

-(void)setImage:(NSString*)imagePath withScaleType:(NSString*)imageScaleType {
    NSLog(@"setimage called");
    imageView = [[UIImageView alloc] initWithFrame:self.viewController.view.bounds];

    if (imageScaleType == nil) {
        NSLog(@"imagescaletype was NIL");
        imageScaleType = DEFAULT_IMAGE_SCALE;
    }

    if ([imageScaleType isEqualToString:@"stretch"]){
        // Stretches image to fill all available background space, disregarding aspect ratio
        imageView.contentMode = UIViewContentModeScaleToFill;
    } else if ([imageScaleType isEqualToString:@"fit"]) {
        // fits entire image perfectly
        imageView.contentMode = UIViewContentModeScaleAspectFit;
    } else if ([imageScaleType isEqualToString:@"aspectStretch"]) {
        // Stretches image to fill all possible space while retaining aspect ratio
        imageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        // Places image in the center of the screen
        imageView.contentMode = UIViewContentModeCenter;
        //moviePlayer.backgroundView.contentMode = UIViewContentModeCenter;
    }

    [imageView setImage:[self getImage:imagePath]];
}

-(void)startPlayer:(NSString*)uri {
    NSLog(@"startplayer called");
    NSURL *url             =  [NSURL URLWithString:uri];
    movie                  =  [AVPlayer playerWithURL:url];

    // handle orientation
    [self handleOrientation];

    // handle gestures
    [self handleGestures];

    // add KVO observer for movie rate
    [movie addObserver:self
                       forKeyPath:@"rate"
                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                          context:0];

    [moviePlayer setPlayer:movie];
    if (controls == 0 || controls == 1) {
        [moviePlayer setShowsPlaybackControls:NO];
        if (controls == 1) {
            [self setSimpleControls];
        }
    } else {
        [moviePlayer setShowsPlaybackControls:YES];
    }
    [moviePlayer setUpdatesNowPlayingInfoCenter:YES];

    if(@available(iOS 11.0, *)) { [moviePlayer setEntersFullScreenWhenPlaybackBegins:YES]; }

    // present modally so we get a close button
    [self.viewController presentViewController:moviePlayer animated:YES completion:^(void){
        if (self->startTimeInMs && self->moviePlayer.player.status == AVPlayerStatusReadyToPlay) {
            int32_t timeScale = self->moviePlayer.player.currentItem.asset.duration.timescale;
            CMTime seektime = CMTimeMakeWithSeconds([self->startTimeInMs intValue]/1000, timeScale);
            [self->moviePlayer.player seekToTime:seektime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        [self->moviePlayer.player play];
    }];

    // add audio image and background color
    if ([videoType isEqualToString:TYPE_AUDIO]) {
        if (imageView != nil) {
            [moviePlayer.contentOverlayView setAutoresizesSubviews:YES];
            [moviePlayer.contentOverlayView addSubview:imageView];
        }
        if (startTimeInMs) {
            int32_t timeScale = moviePlayer.player.currentItem.asset.duration.timescale;
            CMTime seektime = CMTimeMakeWithSeconds([startTimeInMs intValue]/1000, timeScale);
            [moviePlayer.player seekToTime:seektime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        moviePlayer.contentOverlayView.backgroundColor = backgroundColor;
        [self.viewController.view addSubview:moviePlayer.view];
    }

    // setup listners
    [self handleListeners];
}

- (void) handleListeners {

    // Listen for re-maximize
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    // Listen for minimize
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    // Listen for playback finishing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];

    // Listen for errors
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];

    // Listen for orientation change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];

    /* Listen for click on the "Done" button

     // Deprecated.. AVPlayerController doesn't offer a "Done" listener... thanks apple. We'll listen for an error when playback finishes
     [[NSNotificationCenter defaultCenter] addObserver:self
     selector:@selector(doneButtonClick:)
     name:MPMoviePlayerWillExitFullscreenNotification
     object:nil];
     */
}

- (void) handleGestures {
    // Get buried nested view
    UIView *contentView = [moviePlayer.view valueForKey:@"contentView"];

    // loop through gestures, remove swipes
    for (UIGestureRecognizer *recognizer in contentView.gestureRecognizers) {
        NSLog(@"gesture loop ");
        NSLog(@"%@", recognizer);
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
    }
}

- (void) handleOrientation {
    // hnadle the subclassing of the view based on the orientation variable
    if ([mOrientation isEqualToString:@"landscape"]) {
        moviePlayer            =  [[LandscapeAVPlayerViewController alloc] init];
    } else if ([mOrientation isEqualToString:@"portrait"]) {
        moviePlayer            =  [[PortraitAVPlayerViewController alloc] init];
    } else {
        moviePlayer            =  [[AVPlayerViewController alloc] init];
    }
}

- (void) appDidEnterBackground:(NSNotification*)notification {
    NSLog(@"appDidEnterBackground");

    if (moviePlayer && movie && videoType == TYPE_AUDIO)
    {
        NSLog(@"did set player layer to nil");
        [moviePlayer setPlayer: nil];
    }
}

- (void) appDidBecomeActive:(NSNotification*)notification {
    NSLog(@"appDidBecomeActive");

    if (moviePlayer && movie && videoType == TYPE_AUDIO)
    {
        NSLog(@"did reinstate playerlayer");
        [moviePlayer setPlayer:movie];
    }
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification {
    NSLog(@"Playback did finish with auto close being %d, and error message being %@", shouldAutoClose, notification.userInfo);
    NSDictionary *notificationUserInfo = [notification userInfo];
    NSNumber *errorValue = [notificationUserInfo objectForKey:AVPlayerItemFailedToPlayToEndTimeErrorKey];
    NSString *errorMsg;
    if (errorValue) {
        NSError *mediaPlayerError = [notificationUserInfo objectForKey:@"error"];
        if (mediaPlayerError) {
            errorMsg = [mediaPlayerError localizedDescription];
        } else {
            errorMsg = @"Unknown error.";
        }
        NSLog(@"Playback failed: %@", errorMsg);
    }

    if (shouldAutoClose || [errorMsg length] != 0) {
        [self cleanup];
        CDVPluginResult* pluginResult;
        if ([errorMsg length] != 0) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMsg];
        } else {
            NSNumber *currentPosition = [NSNumber numberWithFloat:CMTimeGetSeconds(movie.currentItem.currentTime)*1000];
            NSNumber *mediaDuration = [NSNumber numberWithFloat:CMTimeGetSeconds(movie.currentItem.duration)*1000];

            if ([currentPosition isEqualToNumber:@0]) {
                return;
            }

            NSDictionary *message = @{@"currentPositionInMs": currentPosition,
                                      @"finishedTheMedia": @YES,
                                      @"mediaDurationInMs": mediaDuration};

            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    }
}


- (void)cleanup {
    NSLog(@"Clean up called");
    imageView = nil;
    initFullscreen = false;
    backgroundColor = nil;

    // Remove playback finished listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemDidPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove playback finished error listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemFailedToPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove orientation change listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIDeviceOrientationDidChangeNotification
     object:nil];

    if (movie.observationInfo) {
        [movie removeObserver:self forKeyPath:@"rate"];
    }

    if (moviePlayer) {
        [moviePlayer.player pause];
        [moviePlayer dismissViewControllerAnimated:YES completion:nil];
        moviePlayer = nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    // Observe rate key value (0=stopped, 1=play)
    if ([keyPath isEqualToString:@"rate"]) {
        if ([movie rate]) {
            NSLog(@"Play");
        } else {
            NSLog(@"Pause");
            NSNumber *currentPosition = [NSNumber numberWithFloat:CMTimeGetSeconds(movie.currentItem.currentTime)*1000];
            NSNumber *mediaDuration = [NSNumber numberWithFloat:CMTimeGetSeconds(movie.currentItem.duration)*1000];

            if ([currentPosition isEqualToNumber:@0]) {
                return;
            }

            NSDictionary *message = @{@"currentPositionInMs": currentPosition,
                                      @"finishedTheMedia": @NO,
                                      @"mediaDurationInMs": mediaDuration};
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
            result.keepCallback = [NSNumber numberWithBool:YES];
            [self.commandDelegate sendPluginResult:result callbackId:callbackId];
        }
    }
}

- (void)setSimpleControls {
    playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    playPauseButton.frame = CGRectMake(0, 0, 100, 100);
    playPauseButton.center = moviePlayer.view.center;
    [moviePlayer.contentOverlayView addSubview:playPauseButton];
    [playPauseButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateNormal];
    [playPauseButton addTarget:self action:@selector(togglePlayPause) forControlEvents:UIControlEventTouchUpInside];
    
    if (@available(iOS 13.0, *)) {
        closeButton = [UIButton buttonWithType:UIButtonTypeClose];
    } else {
        closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [closeButton setTitle:@"X" forState:UIControlStateNormal];
    }
    closeButton.frame = CGRectMake(64, 16, 40, 40);
    [moviePlayer.contentOverlayView addSubview:closeButton];
    [closeButton addTarget:self action:@selector(cleanup) forControlEvents:UIControlEventTouchUpInside];
    
    overlayShown = YES;
    UIButton *overlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [overlayButton addTarget:self action:@selector(toggleOverlay) forControlEvents:UIControlEventTouchUpInside];
    overlayButton.frame = self.viewController.view.bounds;
    [moviePlayer.contentOverlayView addSubview:overlayButton];
    
    [moviePlayer.contentOverlayView bringSubviewToFront:playPauseButton];
    [moviePlayer.contentOverlayView bringSubviewToFront:closeButton];
    
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(cleanup)];
    [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    [moviePlayer.contentOverlayView addGestureRecognizer:swipeDown];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->overlayShown) {
            [self toggleOverlay];
        }
    });
}

- (void)togglePlayPause {
    if ([movie rate]) {
        [playPauseButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateNormal];
        [movie pause];
    } else {
        [playPauseButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateNormal];
        [movie play];
    }
}

- (void)toggleOverlay {
    if (overlayShown) {
        [UIView animateWithDuration:0.3 animations:^{
            self->playPauseButton.alpha = 0;
            [self->playPauseButton setHidden:YES];
            self->closeButton.alpha = 0;
            [self->closeButton setHidden:YES];
            self->overlayShown = NO;
        }];
        return;
    }
    
    [UIView animateWithDuration:0.3 animations:^{
        self->playPauseButton.alpha = 1;
        [self->playPauseButton setHidden:NO];
        self->closeButton.alpha = 1;
        [self->closeButton setHidden:NO];
        self->overlayShown = YES;
    }];
}

@end
