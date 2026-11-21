package com.tmoath07.reboxtvreceiver;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.TextView;
import android.widget.FrameLayout;
import android.util.DisplayMetrics;

import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class SubtitleOverlayService extends Service {
    private final Handler main = new Handler(Looper.getMainLooper());
    private ScheduledExecutorService executor;
    private WindowManager manager;
    private WindowManager.LayoutParams layout;
    private FrameLayout container;
    private TextView subtitle;
    private String source = "";

    @Override public IBinder onBind(Intent intent) { return null; }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.getStringExtra("source") != null) {
            source = intent.getStringExtra("source").trim()
                .replaceAll("/(tv|state)/?$", "").replaceAll("/+$", "");
        }
        startNotification();
        if (!Settings.canDrawOverlays(this)) {
            stopSelf();
            return START_NOT_STICKY;
        }
        if (container == null) setupOverlay();
        if (executor != null) executor.shutdownNow();
        executor = Executors.newSingleThreadScheduledExecutor();
        executor.scheduleWithFixedDelay(this::fetchCaption, 0, 850, TimeUnit.MILLISECONDS);
        return START_NOT_STICKY;
    }

    private void startNotification() {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel("tv_caption", "REBOX TV subtitle receiver", NotificationManager.IMPORTANCE_LOW));
        Notification note = new Notification.Builder(this, "tv_caption")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle("REBOX TV Receiver")
            .setContentText("استقبال الترجمة على التلفزيون")
            .build();
        startForeground(3001, note);
    }

    private void setupOverlay() {
        manager = (WindowManager) getSystemService(WINDOW_SERVICE);
        container = new FrameLayout(this);
        subtitle = new TextView(this);
        subtitle.setTextColor(Color.CYAN);
        subtitle.setTextSize(25);
        subtitle.setGravity(Gravity.CENTER);
        subtitle.setPadding(18, 10, 18, 10);
        subtitle.setVisibility(TextView.GONE);
        container.addView(subtitle, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT));
        layout = new WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE |
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        );
        layout.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        layout.y = 400;
        manager.addView(container, layout);
    }

    private void fetchCaption() {
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL(source + "/state").openConnection();
            connection.setConnectTimeout(2300);
            connection.setReadTimeout(2300);
            connection.setUseCaches(false);
            try (InputStream stream = connection.getInputStream();
                 ByteArrayOutputStream bytes = new ByteArrayOutputStream()) {
                byte[] chunk = new byte[4096];
                int n;
                while ((n = stream.read(chunk)) != -1) {
                    bytes.write(chunk, 0, n);
                    if (bytes.size() > 50000) break;
                }
                JSONObject json = new JSONObject(new String(bytes.toByteArray(), StandardCharsets.UTF_8));
                main.post(() -> display(json));
            }
        } catch (Exception ignored) {
            // Keep the previous subtitle until the sender becomes available again.
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    private void display(JSONObject json) {
        if (subtitle == null || manager == null) return;
        String text = json.optString("subtitle", "");
        subtitle.setText(text);
        subtitle.setVisibility(text.isEmpty() ? TextView.GONE : TextView.VISIBLE);
        subtitle.setTextSize((float) json.optDouble("fontSize", 25));
        try { subtitle.setTextColor(Color.parseColor(json.optString("color", "#FFFFFF"))); }
        catch (Exception ignored) { subtitle.setTextColor(Color.WHITE); }
        int background;
        try { background = Color.parseColor(json.optString("background", "#000000")); }
        catch (Exception ignored) { background = Color.BLACK; }
        int opacity = (int) Math.round(Math.max(0, Math.min(1, json.optDouble("opacity", .75))) * 255);
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(Color.argb(opacity, Color.red(background), Color.green(background), Color.blue(background)));
        shape.setCornerRadius(16);
        subtitle.setBackground(shape);
        DisplayMetrics metrics = getResources().getDisplayMetrics();
        layout.y = (int) (metrics.heightPixels * Math.max(0, Math.min(90, json.optInt("position", 75))) / 100.0);
        try { manager.updateViewLayout(container, layout); }
        catch (Exception ignored) {}
    }

    @Override public void onDestroy() {
        if (executor != null) executor.shutdownNow();
        if (manager != null && container != null) {
            try { manager.removeView(container); } catch (Exception ignored) {}
        }
        super.onDestroy();
    }
}
