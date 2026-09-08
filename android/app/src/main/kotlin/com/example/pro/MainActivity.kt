package com.example.pro

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onBackPressed() {
        moveTaskToBack(true)
    }
}