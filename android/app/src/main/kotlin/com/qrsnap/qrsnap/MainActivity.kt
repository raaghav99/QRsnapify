package com.qrsnap.qrsnap

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

private const val TAG = "QRSnapPDF"

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "qrsnap/pdf"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "generatePdf") {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("NO_URL", "URL is required", null)
                    } else {
                        generatePdf(url, result)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun generatePdf(url: String, result: MethodChannel.Result) {
        Handler(Looper.getMainLooper()).post {
            var resultSent = false
            var cleanedUp = false

            // Forces WebView to render the ENTIRE document, not just the visible viewport.
            // Must be called before WebView is created.
            WebView.enableSlowWholeDocumentDraw()

            val webView = WebView(this)
            webView.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                loadWithOverviewMode = true
                useWideViewPort = true
            }
            webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null)

            val container = FrameLayout(this)
            container.alpha = 0f
            val root = window.decorView.rootView as ViewGroup
            root.addView(container, ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
            container.addView(webView, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))

            fun cleanup() {
                if (cleanedUp) return
                cleanedUp = true
                root.removeView(container)
                webView.destroy()
            }

            fun sendError(code: String, msg: String) {
                if (!resultSent) {
                    resultSent = true
                    cleanup()
                    result.error(code, msg, null)
                }
            }

            fun pollUntilStable(lastHeight: Int, stableCount: Int, iteration: Int, onStable: (Int) -> Unit) {
                if (resultSent) return
                if (iteration > 30) {
                    sendError("TIMEOUT", "Page content did not stabilize after 15s")
                    return
                }
                webView.evaluateJavascript(
                    "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
                ) { heightStr ->
                    if (resultSent) return@evaluateJavascript
                    val h = heightStr.trim().toIntOrNull() ?: 0
                    val newStableCount = if (h > 0 && h == lastHeight) stableCount + 1 else 0
                    if (newStableCount >= 3) {
                        onStable(h)
                    } else {
                        Handler(Looper.getMainLooper()).postDelayed({
                            pollUntilStable(h, newStableCount, iteration + 1, onStable)
                        }, 500)
                    }
                }
            }

            // Timeout: 45s
            Handler(Looper.getMainLooper()).postDelayed({
                sendError("TIMEOUT", "PDF generation timed out after 45s")
            }, 45_000)

            webView.webViewClient = object : WebViewClient() {
                private var handled = false

                override fun onPageFinished(view: WebView, pageUrl: String) {
                    if (handled) return
                    handled = true

                    Handler(Looper.getMainLooper()).postDelayed({
                    pollUntilStable(0, 0, 0) { cssHeight ->
                        if (resultSent) return@pollUntilStable
                        val contentWidth = view.width
                        val viewportH = view.height.takeIf { it > 0 } ?: 1200

                        if (cssHeight <= 0 || contentWidth <= 0) {
                            sendError("SIZE_ERROR", "Page has no content")
                            return@pollUntilStable
                        }

                        // Scroll through to trigger lazy-loaded images
                        val density = resources.displayMetrics.density
                        val approxPhysH = (cssHeight * density).toInt()
                        val scrollSteps = (approxPhysH / viewportH) + 1
                        var step = 0

                        fun doScroll() {
                            if (resultSent) return
                            if (step <= scrollSteps) {
                                view.scrollTo(0, step * viewportH)
                                step++
                                Handler(Looper.getMainLooper()).postDelayed({ doScroll() }, 300)
                            } else {
                                // Done scrolling — get physical height, resize, and capture
                                view.scrollTo(0, 0)
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (resultSent) return@postDelayed

                                    view.evaluateJavascript(
                                        "Math.round(Math.max(document.body.scrollHeight, document.documentElement.scrollHeight) * window.devicePixelRatio)"
                                    ) { physStr ->
                                        if (resultSent) return@evaluateJavascript
                                        val physH = physStr.trim().toIntOrNull() ?: (cssHeight * 3)
                                        val cappedHeight = minOf(physH, 25000)
                                        Log.d(TAG, "Capture: ${contentWidth}x${cappedHeight} (css=$cssHeight phys=$physH)")

                                        // Resize WebView to full content height.
                                        // enableSlowWholeDocumentDraw() ensures draw() renders ALL of it.
                                        view.measure(
                                            View.MeasureSpec.makeMeasureSpec(contentWidth, View.MeasureSpec.EXACTLY),
                                            View.MeasureSpec.makeMeasureSpec(cappedHeight, View.MeasureSpec.EXACTLY)
                                        )
                                        view.layout(0, 0, contentWidth, cappedHeight)

                                        // Wait for the resize to take effect
                                        Handler(Looper.getMainLooper()).postDelayed({
                                            if (resultSent) return@postDelayed
                                            try {
                                                val bitmap = Bitmap.createBitmap(contentWidth, cappedHeight, Bitmap.Config.ARGB_8888)
                                                view.draw(Canvas(bitmap))
                                                Log.d(TAG, "Bitmap captured")
                                                cleanup()

                                                // Generate PDF on background thread
                                                val outputFile = File(cacheDir, "qrsnap_${System.currentTimeMillis()}.pdf")
                                                val a4W = 595
                                                val a4H = 842
                                                val scale = a4W.toFloat() / contentWidth.toFloat()
                                                val totalPdfH = (cappedHeight * scale).toInt()

                                                Thread {
                                                    try {
                                                        val pdfDoc = PdfDocument()
                                                        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
                                                        var pageNum = 1

                                                        // Pre-compute smart break points in bitmap coordinates.
                                                        // For each page boundary, scan nearby rows to find
                                                        // the "emptiest" row (most uniform color = gap between content).
                                                        val idealSliceH = (a4H / scale).toInt() // one A4 page in bitmap px
                                                        val searchZone = (idealSliceH * 0.12).toInt() // look ±12% around boundary
                                                        val breakPoints = mutableListOf(0) // first page starts at 0
                                                        var bmpY = 0
                                                        while (bmpY + idealSliceH < cappedHeight) {
                                                            val idealBreak = bmpY + idealSliceH
                                                            val scanFrom = maxOf(bmpY + idealSliceH - searchZone, bmpY + 1)
                                                            val scanTo = minOf(idealBreak + searchZone, cappedHeight - 1)
                                                            var bestRow = idealBreak.coerceAtMost(cappedHeight - 1)
                                                            var bestScore = Long.MAX_VALUE

                                                            // Sample every 2nd pixel for speed; score = variance of color across row
                                                            val rowPixels = IntArray(contentWidth)
                                                            for (row in scanFrom..scanTo) {
                                                                bitmap.getPixels(rowPixels, 0, contentWidth, 0, row, contentWidth, 1)
                                                                // Score: sum of abs differences between adjacent pixels.
                                                                // A uniform row (solid bg) scores ~0; a row with content scores high.
                                                                var score = 0L
                                                                var prev = rowPixels[0]
                                                                for (x in 2 until contentWidth step 2) {
                                                                    val px = rowPixels[x]
                                                                    val dr = ((px shr 16) and 0xFF) - ((prev shr 16) and 0xFF)
                                                                    val dg = ((px shr 8) and 0xFF) - ((prev shr 8) and 0xFF)
                                                                    val db = (px and 0xFF) - (prev and 0xFF)
                                                                    score += (dr * dr + dg * dg + db * db).toLong()
                                                                    prev = px
                                                                }
                                                                if (score < bestScore) {
                                                                    bestScore = score
                                                                    bestRow = row
                                                                }
                                                            }
                                                            breakPoints.add(bestRow)
                                                            bmpY = bestRow
                                                        }
                                                        breakPoints.add(cappedHeight) // sentinel: end of content
                                                        Log.d(TAG, "Smart breaks: ${breakPoints.size - 1} pages, breaks=$breakPoints")

                                                        // Clone exact edge pixel row 1pt at each break boundary
                                                        val blendPt = 1 // PDF points of cloned-edge padding

                                                        for (i in 0 until breakPoints.size - 1) {
                                                            val srcY = breakPoints[i]
                                                            val srcBottom = breakPoints[i + 1]
                                                            val srcH = srcBottom - srcY
                                                            if (srcH <= 0) continue

                                                            val isFirst = i == 0
                                                            val isLast = i == breakPoints.size - 2
                                                            val topBlend = if (isFirst) 0 else blendPt
                                                            val botBlend = if (isLast) 0 else blendPt
                                                            val contentH = (srcH * scale).toInt().coerceIn(1, a4H)
                                                            val pageH = contentH + topBlend + botBlend
                                                            val pageInfo = PdfDocument.PageInfo.Builder(a4W, pageH, pageNum).create()
                                                            val page = pdfDoc.startPage(pageInfo)

                                                            if (topBlend > 0) {
                                                                val rowBmp = Bitmap.createBitmap(bitmap, 0, srcY, contentWidth, 1)
                                                                for (r in 0 until topBlend) {
                                                                    val d = RectF(0f, r.toFloat(), a4W.toFloat(), (r + 1).toFloat())
                                                                    page.canvas.drawBitmap(rowBmp, null, d, paint)
                                                                }
                                                                rowBmp.recycle()
                                                            }

                                                            val src = Rect(0, srcY, contentWidth, srcBottom)
                                                            val dst = RectF(0f, topBlend.toFloat(), a4W.toFloat(), (topBlend + contentH).toFloat())
                                                            page.canvas.drawBitmap(bitmap, src, dst, paint)

                                                            if (botBlend > 0) {
                                                                val rowBmp = Bitmap.createBitmap(bitmap, 0, (srcBottom - 1).coerceAtMost(cappedHeight - 1), contentWidth, 1)
                                                                for (r in 0 until botBlend) {
                                                                    val y = topBlend + contentH + r
                                                                    val d = RectF(0f, y.toFloat(), a4W.toFloat(), (y + 1).toFloat())
                                                                    page.canvas.drawBitmap(rowBmp, null, d, paint)
                                                                }
                                                                rowBmp.recycle()
                                                            }

                                                            pdfDoc.finishPage(page)
                                                            pageNum++
                                                        }

                                                        FileOutputStream(outputFile).use { pdfDoc.writeTo(it) }
                                                        pdfDoc.close()
                                                        bitmap.recycle()
                                                        Log.d(TAG, "PDF done: $pageNum pages")

                                                        Handler(Looper.getMainLooper()).post {
                                                            if (!resultSent) {
                                                                resultSent = true
                                                                result.success(outputFile.absolutePath)
                                                            }
                                                        }
                                                    } catch (e: Exception) {
                                                        bitmap.recycle()
                                                        Handler(Looper.getMainLooper()).post {
                                                            sendError("PDF_ERROR", e.message ?: "Unknown error")
                                                        }
                                                    }
                                                }.start()

                                            } catch (e: OutOfMemoryError) {
                                                Log.e(TAG, "OOM", e)
                                                sendError("OOM", "Not enough memory for capture")
                                            } catch (e: Exception) {
                                                Log.e(TAG, "Capture error", e)
                                                sendError("PDF_ERROR", e.message ?: "Unknown error")
                                            }
                                        }, 500) // settle after resize
                                    }
                                }, 500) // settle after scroll-back
                            }
                        }
                        doScroll()
                    }
                    }, 800) // initial page settle
                }

                @Deprecated("Deprecated in Java")
                override fun onReceivedError(view: WebView, errorCode: Int, description: String, failingUrl: String) {
                    if (failingUrl == url) {
                        sendError("LOAD_ERROR", "$errorCode: $description")
                    }
                }

                override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                    if (request.isForMainFrame) {
                        sendError("LOAD_ERROR", "${error.errorCode}: ${error.description}")
                    }
                }
            }

            webView.loadUrl(url)
        }
    }
}
