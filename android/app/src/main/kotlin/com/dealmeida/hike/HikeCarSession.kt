package com.dealmeida.hike

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session

class HikeCarSession : Session() {
    override fun onCreateScreen(intent: Intent): Screen =
        HikeCarScreen(carContext)
}
