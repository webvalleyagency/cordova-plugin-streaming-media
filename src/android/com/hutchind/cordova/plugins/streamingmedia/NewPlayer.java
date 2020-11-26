package com.hutchind.cordova.plugins.streamingmedia;

import android.annotation.SuppressLint;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.RelativeLayout;
import android.graphics.Color;
import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.Intent;

import com.google.android.exoplayer2.*;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.ui.*;
import com.google.android.exoplayer2.ui.PlayerView;
import com.google.android.exoplayer2.util.*;
import com.google.android.exoplayer2.util.Util;
import com.google.android.exoplayer2.ExoPlaybackException;


public class NewPlayer extends Activity {

    private PlaybackStateListener playbackStateListener;
    private static final String TAG = NewPlayer.class.getName();

    private PlayerView playerView;
    private SimpleExoPlayer player;
    private boolean playWhenReady = true;
    private int currentWindow = 0;
    private long playbackPosition = 0;
    private long mediaDuration = 0;

	private String mediaUrl;
	private Boolean shouldAutoClose = true;
	private boolean showControls;
	private Boolean finishedTheMedia = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.requestWindowFeature(Window.FEATURE_NO_TITLE);
        this.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);

        playbackStateListener = new PlaybackStateListener();
        playerView = new PlayerView(this);

        Bundle b = getIntent().getExtras();
        mediaUrl = b.getString("mediaUrl");
        shouldAutoClose = b.getBoolean("shouldAutoClose", true);
        showControls = b.getBoolean("controls", true);
        playbackPosition = b.getInt("startTimeInMs", 0);

        playerView.setBackgroundColor(Color.BLACK);
        RelativeLayout.LayoutParams playerViewParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        playerViewParams.addRule(RelativeLayout.CENTER_IN_PARENT, RelativeLayout.TRUE);

        setOrientation(b.getString("orientation"));
        setContentView(playerView, playerViewParams);
    }

    private void setOrientation(String orientation) {
		if ("landscape".equals(orientation)) {
			this.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
		}else if("portrait".equals(orientation)) {
			this.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
		}
	}

    @Override
    public void onStart() {
        super.onStart();
        if (Util.SDK_INT > 23) {
            initializePlayer();
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        // hideSystemUi();
        if ((Util.SDK_INT <= 23 || player == null)) {
            initializePlayer();
        }
    }

    @Override
    public void onPause() {
        super.onPause();
        if (Util.SDK_INT <= 23) {
            releasePlayer();
        }
    }

    @Override
    public void onStop() {
        super.onStop();
        if (Util.SDK_INT > 23) {
            releasePlayer();
        }
    }

    @Override
	public void onBackPressed() {
		releasePlayer();
	}

    private void initializePlayer() {
        if (player == null) {
            player = new SimpleExoPlayer.Builder(this).build();
        }

        playerView.setPlayer(player);
        MediaItem mediaItem = MediaItem.fromUri(Uri.parse(mediaUrl));
        player.setMediaItem(mediaItem);

        player.setPlayWhenReady(playWhenReady);
        player.seekTo(currentWindow, playbackPosition);
        player.addListener(playbackStateListener);
        player.prepare();
    }

    private void releasePlayer() {
        if (player != null) {
            playbackPosition = player.getCurrentPosition();
            mediaDuration = player.getDuration();
            currentWindow = player.getCurrentWindowIndex();
            playWhenReady = player.getPlayWhenReady();
            player.removeListener(playbackStateListener);
            player.release();
            player = null;
        }

        sendResponseToParent(RESULT_OK, null);
    }

    private void sendResponseToParent(int resultCode, String message) {
        Intent intent = new Intent();

        intent.putExtra("errorMessage", message);
        intent.putExtra("currentPositionInMs", playbackPosition);
        intent.putExtra("mediaDurationInMs", mediaDuration);
        intent.putExtra("finishedTheMedia", finishedTheMedia);
        setResult(resultCode, intent);
        finish();
    }

    private class PlaybackStateListener implements Player.EventListener {

        @Override
        public void onPlaybackStateChanged(int playbackState) {
            String stateString;
            switch (playbackState) {
            case ExoPlayer.STATE_IDLE:
                stateString = "ExoPlayer.STATE_IDLE      -";
                break;
            case ExoPlayer.STATE_BUFFERING:
                stateString = "ExoPlayer.STATE_BUFFERING -";
                break;
            case ExoPlayer.STATE_READY:
                stateString = "ExoPlayer.STATE_READY     -";
                break;
            case ExoPlayer.STATE_ENDED:
                finishedTheMedia = true;

                if (shouldAutoClose) {
                    sendResponseToParent(RESULT_OK, null);
                }

                stateString = "ExoPlayer.STATE_ENDED     -";
                break;
            default:
                stateString = "UNKNOWN_STATE             -";
                break;
            }
            Log.d(TAG, "changed state to " + stateString);
        }

        @Override
        public void onPlayerError(ExoPlaybackException error) {
            sendResponseToParent(RESULT_CANCELED, error.getMessage());
        }
    }

}
