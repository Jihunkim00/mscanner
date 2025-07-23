package com.thj.mscanner

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ✅ Edge-to-Edge UI를 적용하기 위한 코드
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
