package com.isan.isan_flutter;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class IsanWebViewFactory extends PlatformViewFactory {

    private final BinaryMessenger messenger;

    public IsanWebViewFactory(BinaryMessenger messenger) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
    }

    @NonNull
    @Override
    public PlatformView create(@NonNull Context context, int viewId, @Nullable Object args) {
        @SuppressWarnings("unchecked")
        Map<String, Object> params = (Map<String, Object>) args;
        return new IsanWebViewPlatformView(context, messenger, viewId, params);
    }
}
