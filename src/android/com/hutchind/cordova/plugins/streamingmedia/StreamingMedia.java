package com.hutchind.cordova.plugins.streamingmedia;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.util.Log;
import android.content.ContentResolver;
import android.content.Intent;
import android.os.Build;
import java.util.Iterator;
import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONException;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;

public class StreamingMedia extends CordovaPlugin {
	public static final String ACTION_PLAY_AUDIO = "playAudio";
	public static final String ACTION_PLAY_VIDEO = "playVideo";

	private static final int ACTIVITY_CODE_PLAY_MEDIA = 7;

	private CallbackContext callbackContext;

	private static final String TAG = "StreamingMediaPlugin";

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		this.callbackContext = callbackContext;
		JSONObject options = null;

        final CordovaInterface cordovaObj = cordova;
		final CordovaPlugin plugin = this;

		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				final Intent streamIntent = new Intent(cordovaObj.getActivity().getApplicationContext(), MainActivity.class);

				cordovaObj.startActivityForResult(plugin, streamIntent, ACTIVITY_CODE_PLAY_MEDIA);
			}
		});

        return true;
	}

	public void onActivityResult(int requestCode, int resultCode, Intent intent) {
		Log.v(TAG, "onActivityResult: " + requestCode + " " + resultCode);
		super.onActivityResult(requestCode, resultCode, intent);
		if (ACTIVITY_CODE_PLAY_MEDIA == requestCode) {
			JSONObject resultData = new JSONObject();
			if (intent != null) {
				tryToPutPropertyToObject(resultData, "currentPositionInMs", intent.getLongExtra("currentPositionInMs", -1));
				tryToPutPropertyToObject(resultData, "mediaDurationInMs", intent.getLongExtra("mediaDurationInMs", -1));
				tryToPutPropertyToObject(resultData, "finishedTheMedia", intent.getBooleanExtra("finishedTheMedia", false));
				tryToPutPropertyToObject(resultData, "errorMessage", intent.getStringExtra("errorMessage"));
			}

			if (Activity.RESULT_OK == resultCode) {
				this.callbackContext.success(resultData);
			} else if (Activity.RESULT_CANCELED == resultCode) {
				this.callbackContext.error(resultData);
			}
		}
	}

	private <VALUE_TYPE> JSONObject tryToPutPropertyToObject(JSONObject object, String key, VALUE_TYPE value) {
		try {
			object.put(key, value);
		} catch (JSONException e) {
			Log.e(TAG, "JSONException while trying to set property: '" + key + "' with value: '" + value + "'");
		}

		return object;
	}
}