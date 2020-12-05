package com.hutchind.cordova.plugins.streamingmedia;

import com.google.android.gms.cast.framework.CastOptions;
import com.google.android.gms.cast.framework.OptionsProvider;
import com.google.android.gms.cast.framework.SessionProvider;
import com.google.android.gms.cast.CastMediaControlIntent;

import android.content.Context;

import java.util.List;

/**
 * Implements {@link OptionsProvider} to provide {@link CastOptions}.
 */
public class CastOptionsProvider implements OptionsProvider {

    @Override
    public CastOptions getCastOptions(Context context) {
        return new CastOptions.Builder()
                .setReceiverApplicationId(CastMediaControlIntent.DEFAULT_MEDIA_RECEIVER_APPLICATION_ID)
                .build();
    }

    @Override
    public List<SessionProvider> getAdditionalSessionProviders(Context appContext) {
        return null;
    }
}
