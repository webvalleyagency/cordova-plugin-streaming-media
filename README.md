# Cordova Streaming Media plugin

For iOS and Android, by [Nicholas Hutchind](https://github.com/nchutchind)

## Description

This plugin allows you to stream audio and video in a fullscreen, native player on iOS and Android.

* 1.0.0 Works with Cordova 3.x
* 1.0.1+ Works with Cordova >= 4.0

## Message from the maintainer:

I no longer contribute to Cordova or Ionic full time. If your org needs work on this plugin please consider funding it and hiring me for improvements or otherwise consider donating your time and submitting a PR for whatever you need fixed. My contact info can be found [here](https://github.com/shamilovtim). 

## Installation

```
cordova plugin add https://github.com/nchutchind/cordova-plugin-streaming-media
```

### iOS specifics
* Uses the AVPlayerViewController
* Tested on iOS 12 or later

### Android specifics
* Uses VideoView and MediaPlayer.
* Creates two activities in your AndroidManifest.xml file.
* Tested on Android 4.0+

## Usage

```javascript
  const videoUrl = STREAMING_VIDEO_URL;

  // Just play a video
  window.plugins.streamingMedia.playVideo(videoUrl);

  // Play a video with callbacks
  const options = {
    successCallback: function(mediaPlayerResult) {
      console.log('Video was closed without error.');
    },
    errorCallback: function(mediaPlayerResult) {
      console.log(`Error! ${mediaPlayerResult.errorMessage}`);
    },
    orientation: 'landscape',
    shouldAutoClose: true,  // true(default)/false
    controls: true, // true(default)/false. Used to hide controls on fullscreen
    startTimeInMs: 5000 // (optional) Alternatively instead of using this option you can call: window.plugins.streamingMedia.playVideoAtTime(videoUrl, 5000)
  };
  window.plugins.streamingMedia.playVideo(videoUrl, options);


  const audioUrl = STREAMING_AUDIO_URL;

  // Play an audio file (not recommended, since the screen will be plain black)
  window.plugins.streamingMedia.playAudio(audioUrl);

  // Play an audio file with options (all options optional)
  const options = {
    bgColor: '#FFFFFF',
    bgImage: '<SWEET_BACKGROUND_IMAGE>',
    bgImageScale: 'fit', // other valid values: 'stretch', 'aspectStretch'
    initFullscreen: false, // true is default. iOS only.
    keepAwake: false, // prevents device from sleeping. true is default. Android only.
    successCallback: function(mediaPlayerResult) {
      console.log('Player closed without error.');
    },
    errorCallback: function(mediaPlayerResult) {
      console.log(`Error! ${mediaPlayerResult.errorMessage}`);
    },
    startTimeInMs: 5000 // (optional) Alternatively instead of using this option you can call: window.plugins.streamingMedia.playAudioAtTime(audioUrl, 5000)
  };
  window.plugins.streamingMedia.playAudio(audioUrl, options);

  // Stop current audio
  window.plugins.streamingMedia.stopAudio();

  // Pause current audio (iOS only)
  window.plugins.streamingMedia.pauseAudio();

  // Resume current audio (iOS only)
  window.plugins.streamingMedia.resumeAudio();


  // Content of `mediaPlayerResult`
  const mediaPlayerResult = {
    errorMessage: 'Everybody is dead, Dave!', // Present only in `errorCallback`.
    currentPositionInMs: 5000, // Position in media player, when user closed it. When user reached the end of the media, the value is 0 and when then plugin is unable to get the position, the value is -1.
    mediaDurationInMs: 10000, // Length of the media. When the plugin is unable to get it, the value is -1.
    finishedTheMedia: true // True is user reached the end of the media duration.
  }

```

## Special Thanks

[Michael Robinson (@faceleg)](https://github.com/faceleg)

[Timothy Shamilov (@shamilovtim)](https://github.com/shamilovtim)
