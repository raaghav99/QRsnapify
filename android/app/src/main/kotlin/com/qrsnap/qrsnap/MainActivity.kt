package com.qrsnap.qrsnap

import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

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

            val webView = WebView(this)
            webView.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                loadWithOverviewMode = true
                useWideViewPort = true
            }
            // Software rendering = accurate PDF output
            webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null)

            // Attach to window so WebView renders, but invisible so it doesn't flash
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

            // Poll scrollHeight every 500ms; proceed once stable for 3 consecutive checks.
            // No hard timeout — keeps going until content settles (handles slow JS frameworks).
            fun pollUntilStable(lastHeight: Int, stableCount: Int, onStable: (Int) -> Unit) {
                if (resultSent) return
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
                            pollUntilStable(h, newStableCount, onStable)
                        }, 500)
                    }
                }
            }

            webView.webViewClient = object : WebViewClient() {
                private var handled = false

                override fun onPageFinished(view: WebView, pageUrl: String) {
                    if (handled) return
                    handled = true

                    // Poll until content height stabilizes (no fixed wait — handles any JS framework)
                    pollUntilStable(0, 0) { contentHeight ->
                        if (resultSent) return@pollUntilStable
                        val contentWidth = view.width

                        if (contentHeight <= 0 || contentWidth <= 0) {
                            sendError("SIZE_ERROR", "Page has no content ($contentWidth x $contentHeight)")
                            return@pollUntilStable
                        }

                        // Resize WebView to full content height so draw() captures everything
                        view.measure(
                            View.MeasureSpec.makeMeasureSpec(contentWidth, View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(contentHeight, View.MeasureSpec.EXACTLY)
                        )
                        view.layout(0, 0, contentWidth, contentHeight)

                        // Wait 500ms for re-layout to settle after resize
                        Handler(Looper.getMainLooper()).postDelayed({
                            if (resultSent) return@postDelayed
                            try {
                                val outputFile = File(cacheDir, "qrsnap_${System.currentTimeMillis()}.pdf")

                                // A4 at 72 DPI = 595 x 842 points
                                val a4W = 595
                                val a4H = 842
                                val scale = a4W.toFloat() / contentWidth.toFloat()
                                val totalPdfH = (contentHeight * scale).toInt()

                                val pdfDoc = PdfDocument()
                                var yOffset = 0
                                var pageNum = 1

                                while (yOffset < totalPdfH) {
                                    val pageH = minOf(a4H, totalPdfH - yOffset)
                                    val pageInfo = PdfDocument.PageInfo.Builder(a4W, pageH, pageNum).create()
                                    val page = pdfDoc.startPage(pageInfo)
                                    page.canvas.scale(scale, scale)
                                    page.canvas.translate(0f, -yOffset / scale)
                                    view.draw(page.canvas)
                                    pdfDoc.finishPage(page)
                                    yOffset += a4H
                                    pageNum++
                                }

                                FileOutputStream(outputFile).use { fos ->
                                    pdfDoc.writeTo(fos)
                                }
                                pdfDoc.close()

                                if (!resultSent) {
                                    resultSent = true
                                    cleanup()
                                    result.success(outputFile.absolutePath)
                                }
                            } catch (e: Exception) {
                                sendError("PDF_ERROR", e.message ?: "Unknown error")
                            }
                        }, 500)
                    }
                }

                @Deprecated("Deprecated in Java")
                override fun onReceivedError(view: WebView, errorCode: Int, description: String, failingUrl: String) {
                    if (failingUrl == url) {
                        sendError("LOAD_ERROR", "$errorCode: $description")
                    }
                }
            }

            webView.loadUrl(url)
        }
    }
}
