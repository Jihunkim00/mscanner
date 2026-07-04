package com.thj.mscanner

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.enableEdgeToEdge(window)
        super.onCreate(savedInstanceState)
    }
}
