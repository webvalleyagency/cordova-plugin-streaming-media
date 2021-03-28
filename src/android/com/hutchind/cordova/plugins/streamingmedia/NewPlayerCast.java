package com.hutchind.cordova.plugins.streamingmedia;

import android.net.Uri;
import android.util.Log;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.view.Window;
import android.view.WindowManager;
import android.graphics.Color;
import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.content.Intent;
import androidx.appcompat.app.AppCompatActivity;
import android.widget.RelativeLayout;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.ext.cast.CastPlayer;
import com.google.android.exoplayer2.ext.cast.SessionAvailabilityListener;
import com.google.android.exoplayer2.source.ProgressiveMediaSource;
import com.google.android.exoplayer2.ui.PlayerView;
import com.google.android.exoplayer2.ui.PlayerControlView;
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory;
import com.google.android.exoplayer2.util.MimeTypes;
import com.google.android.exoplayer2.util.Util;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.gms.cast.MediaInfo;
import com.google.android.gms.cast.MediaMetadata;
import com.google.android.gms.cast.MediaQueueItem;
import com.google.android.gms.cast.framework.CastButtonFactory;
import com.google.android.gms.cast.framework.CastContext;
import com.google.android.gms.common.images.WebImage;
import com.kubitini.streaming.R; // BEWARE!! Need to rename this or find better solution

public class NewPlayerCast extends Activity implements SessionAvailabilityListener {

    private static final String TAG = NewPlayerCast.class.getName();

    private String videoClipUrl;

    // the local and remote players
    private SimpleExoPlayer exoPlayer = null;
    private CastPlayer castPlayer = null;
    private Player currentPlayer = null;
    private PlaybackStateListener playbackStateListener;

    // views associated with the players
    private PlayerView playerView;
    private PlayerControlView castControlView;

    // the Cast context
    private CastContext castContext;
    private MenuItem castButton;

    // Player state params
    private Boolean playWhenReady = true;
    private int currentWindow = 0;
    private long playbackPosition = 0;
    private long mediaDuration = 0;
    private Boolean finishedTheMedia = false;
    private Boolean shouldAutoClose = true;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        this.requestWindowFeature(Window.FEATURE_NO_TITLE);
        this.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);

        castContext = CastContext.getSharedInstance(this);
        Bundle b = getIntent().getExtras();
        videoClipUrl = b.getString("mediaUrl");
        playbackPosition = b.getInt("startTimeInMs", 0);
        shouldAutoClose = b.getBoolean("shouldAutoClose", true);

        playbackStateListener = new PlaybackStateListener();
        playerView = new PlayerView(this);
        playerView.setBackgroundColor(Color.BLACK);
        playerView.setKeepScreenOn(true);
        RelativeLayout.LayoutParams playerViewParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        playerViewParams.addRule(RelativeLayout.CENTER_IN_PARENT, RelativeLayout.TRUE);

        setOrientation(b.getString("orientation"));
        setContentView(playerView, playerViewParams);

        castControlView = new PlayerControlView(this);
    }

    private void setOrientation(String orientation) {
		if ("landscape".equals(orientation)) {
			this.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);
		}else if("portrait".equals(orientation)) {
			this.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
		}
	}

    /**
     * Starting with API level 24 Android supports multiple windows. As our app can be visible but
     * not active in split window mode, we need to initialize the player in onStart. Before API level
     * 24 we wait as long as possible until we grab resources, so we wait until onResume before
     * initializing the player.
     */
    @Override
    public void onStart() {
        super.onStart();
        if (Util.SDK_INT >= 24) {
            initializePlayers();
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        if (Util.SDK_INT < 24 || exoPlayer == null) {
            initializePlayers();
        }
    }

    /**
     * Before API Level 24 there is no guarantee of onStop being called. So we have to release the
     * player as early as possible in onPause. Starting with API Level 24 (which brought multi and
     * split window mode) onStop is guaranteed to be called. In the paused state our activity is still
     * visible so we wait to release the player until onStop.
     */
    @Override
    public void onPause() {
        super.onPause();
        if (Util.SDK_INT < 24) {
            if (currentPlayer != null) {
                rememberState();
            }
            releaseLocalPlayer();
        }
    }

    @Override
    public void onStop() {
        super.onStop();
        if (Util.SDK_INT >= 24) {
             if (currentPlayer != null) {
                rememberState();
            }
            releaseLocalPlayer();
        }
    }

    /**
     * We release the remote player when activity is destroyed
     */
    @Override
    public void onDestroy() {
        releaseRemotePlayer();
        currentPlayer = null;
        super.onDestroy();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        super.onCreateOptionsMenu(menu);
        getMenuInflater().inflate(R.menu.cast, menu);
        CastButtonFactory.setUpMediaRouteButton(this, menu, R.id.media_route_menu_item);

        return true;
    }

    /**
     * CastPlayer [SessionAvailabilityListener] implementation.
     */
    @Override
    public void onCastSessionAvailable() {
        playOnPlayer(castPlayer);
    }

    @Override
    public void onCastSessionUnavailable() {
        playOnPlayer(exoPlayer);
    }

    @Override
	public void onBackPressed() {
        rememberState();
		releaseRemotePlayer();
        releaseLocalPlayer();
        currentPlayer = null;
	}

    /**
     * Prepares the local and remote players for playback.
     */
    private void initializePlayers() {
        // first thing to do is set up the player to avoid the double initialization that happens
        // sometimes if onStart() runs and then onResume() checks if the player is null
        exoPlayer = new SimpleExoPlayer.Builder(this).build();
        playerView.setPlayer(exoPlayer);

        // create the CastPlayer that communicates with receiver app
        // but because we don't release the CastPlayer on each onPause()/onStop(), we don't have
        // to recreate it if it exists and the Activity wakes up
        if (castPlayer == null) {
            castPlayer = new CastPlayer(castContext);
            castPlayer.setSessionAvailabilityListener(this);
            castControlView.setPlayer(castPlayer);
        }

        // start the playback
        if (castPlayer != null && castPlayer.isCastSessionAvailable() == true) {
            playOnPlayer(castPlayer);
        } else {
            playOnPlayer(exoPlayer);
        }
    }

    /**
     * Sets the video on the current player (local or remote), whichever is active.
     */
    private void startPlayback() {
        // if the current player is the ExoPlayer, play from it
        if (currentPlayer == exoPlayer) {
            MediaItem mediaItem = MediaItem.fromUri(Uri.parse(videoClipUrl));
            exoPlayer.setMediaItem(mediaItem);

            exoPlayer.setPlayWhenReady(playWhenReady);
            exoPlayer.seekTo(currentWindow, playbackPosition);
            exoPlayer.addListener(playbackStateListener);
            exoPlayer.prepare();
        }

        // if the current player is the CastPlayer, play from it
        if (currentPlayer == castPlayer) {
            MediaMetadata metadata = new MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE);
            metadata.putString(MediaMetadata.KEY_TITLE, "Title");
            metadata.putString(MediaMetadata.KEY_SUBTITLE, "Subtitle");

            MediaInfo mediaInfo = new MediaInfo.Builder(videoClipUrl)
                .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                .setContentType(MimeTypes.VIDEO_MP4)
                .setMetadata(metadata)
                .build();
            MediaQueueItem mediaItem = new MediaQueueItem.Builder(mediaInfo).build();
            castPlayer.loadItem(mediaItem, playbackPosition);

            castPlayer.setPlayWhenReady(playWhenReady);
            castPlayer.seekTo(currentWindow, playbackPosition);
            castPlayer.addListener(playbackStateListener);
            castPlayer.prepare();
        }
    }

    /**
     * Sets the current player to the selected player and starts playback.
     */
    private void playOnPlayer(Player player) {
        if (currentPlayer == player) {
            return;
        }

        // save state from the existing player
        if (currentPlayer != null) {
            if (currentPlayer.getPlaybackState() != Player.STATE_ENDED) {
                rememberState();
            }
            currentPlayer.stop(true);
        }

        // set the new player
        currentPlayer = player;

        // set up the playback
        startPlayback();
    }

    /**
     * Remembers the state of the playback of this Player.
     */
    private void rememberState() {
        if (currentPlayer != null) {
            playbackPosition = currentPlayer.getCurrentPosition();
            mediaDuration = currentPlayer.getDuration();
            currentWindow = currentPlayer.getCurrentWindowIndex();
            playWhenReady = currentPlayer.getPlayWhenReady();
        }
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

    /**
     * Releases the resources of the local player back to the system.
     */
    private void releaseLocalPlayer() {
        if (exoPlayer != null) {
            exoPlayer.release();
            exoPlayer = null;
            playerView.setPlayer(null);
        }

        sendResponseToParent(RESULT_OK, null);
    }

    /**
     * Releases the resources of the remote player back to the system.
     */
    private void releaseRemotePlayer() {
        if (castPlayer != null) {
            castPlayer.setSessionAvailabilityListener(null);
            castPlayer.release();
            castPlayer = null;
        }

        sendResponseToParent(RESULT_OK, null);
    }

    private void releasePlayer() {
        if (currentPlayer == exoPlayer) {
            releaseLocalPlayer();
        }

        if (currentPlayer == castPlayer) {
            releaseRemotePlayer();
        }
    }

    private class PlaybackStateListener implements Player.EventListener {

        @Override
        public void onPlaybackStateChanged(int playbackState) {
            String stateString;
            switch (playbackState) {
            case Player.STATE_IDLE:
                stateString = "Player.STATE_IDLE      -";
                break;
            case Player.STATE_BUFFERING:
                stateString = "Player.STATE_BUFFERING -";
                break;
            case Player.STATE_READY:
                stateString = "Player.STATE_READY     -";
                break;
            case Player.STATE_ENDED:
                finishedTheMedia = true;

                if (shouldAutoClose) {
                    releasePlayer();
                }

                stateString = "Player.STATE_ENDED     -";
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
