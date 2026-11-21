package com.tmoath07.reboxtvreceiver;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

public class MainActivity extends Activity {
    private EditText address;
    private TextView status;

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Color.rgb(11, 15, 26));
        root.setPadding(40, 36, 40, 40);
        root.setFocusableInTouchMode(true);

        TextView heading = new TextView(this);
        heading.setText("REBOX TV Receiver");
        heading.setTextColor(Color.rgb(90, 220, 250));
        heading.setTextSize(30);
        root.addView(heading);

        TextView info = new TextView(this);
        info.setText("عرض الترجمة من تطبيق REBOX TV على هاتفك. افتح التطبيق على نفس شبكة Wi-Fi وانسخ عنوان المستقبل.");
        info.setTextColor(Color.WHITE);
        info.setTextSize(19);
        info.setPadding(0, 20, 0, 24);
        root.addView(info);

        address = new EditText(this);
        address.setText(getPreferences(MODE_PRIVATE).getString("url", "http://192.168.0.100:8080"));
        address.setSingleLine(true);
        address.setTextSize(19);
        address.setTextColor(Color.WHITE);
        address.setHint("http://PHONE_IP:8080");
        address.setHintTextColor(Color.GRAY);
        root.addView(address, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        Button grant = button("1 - منح صلاحية الظهور فوق التطبيقات");
        root.addView(grant);
        grant.setOnClickListener(v -> {
            Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + getPackageName()));
            startActivity(intent);
        });

        Button begin = button("2 - تشغيل ترجمة التلفزيون");
        root.addView(begin);
        begin.setOnClickListener(v -> {
            if (!Settings.canDrawOverlays(this)) {
                status.setText("فعّل صلاحية الظهور فوق التطبيقات أولًا");
                return;
            }
            String base = address.getText().toString().trim();
            if (!(base.startsWith("http://") || base.startsWith("https://"))) {
                status.setText("أدخل عنوان HTTP صحيح من تطبيق الجوال");
                return;
            }
            getPreferences(MODE_PRIVATE).edit().putString("url", base).apply();
            Intent service = new Intent(this, SubtitleOverlayService.class);
            service.putExtra("source", base);
            try {
                startForegroundService(service);
                status.setText("تم بدء استقبال الترجمة. ارجع إلى مدخل HDMI وجرب اللعبة.");
            } catch (Exception exception) {
                status.setText("تعذر بدء العرض: " + exception.getMessage());
            }
        });

        Button stop = button("إيقاف الترجمة");
        root.addView(stop);
        stop.setOnClickListener(v -> {
            stopService(new Intent(this, SubtitleOverlayService.class));
            status.setText("تم إيقاف العرض");
        });

        status = new TextView(this);
        status.setText("ملاحظة: الظهور فوق HDMI نفسه يعتمد على نظام التلفزيون وقد لا يعمل على كل الأجهزة.");
        status.setTextColor(Color.LTGRAY);
        status.setTextSize(17);
        status.setPadding(0, 18, 0, 0);
        root.addView(status);
        setContentView(root);
    }

    private Button button(String label) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextSize(17);
        button.setAllCaps(false);
        return button;
    }
}
