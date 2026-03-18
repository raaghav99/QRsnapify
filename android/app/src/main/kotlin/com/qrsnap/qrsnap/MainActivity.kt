package com.qrsnap.qrsnap

import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
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

            // Attach to the window so the WebView renders properly
            val container = FrameLayout(this)
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

            webView.webViewClient = object : WebViewClient() {
                private var handled = false

                override fun onPageFinished(view: WebView, pageUrl: String) {
                    if (handled) return
                    handled = true

                    // Wait 2s for JS to finish rendering
                    Handler(Looper.getMainLooper()).postDelayed({
                        if (resultSent) return@postDelayed
                        try {
                            val outputFile = File(cacheDir, "qrsnap_${System.currentTimeMillis()}.pdf")
                            val adapter = view.createPrintDocumentAdapter("QRSnap")

                            val attrs = PrintAttributes.Builder()
                                .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                                .setResolution(PrintAttributes.Resolution("res", "res", 300, 300))
                                .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                                .build()

                            adapter.onLayout(null, attrs, null,
                                object : PrintDocumentAdapter.LayoutResultCallback() {
                                    override fun onLayoutFinished(info: PrintDocumentInfo, changed: Boolean) {
                                        try {
                                            val fd = ParcelFileDescriptor.open(
                                                outputFile,
                                                ParcelFileDescriptor.MODE_READ_WRITE or
                                                ParcelFileDescriptor.MODE_CREATE or
                                                ParcelFileDescriptor.MODE_TRUNCATE
                                            )
                                            adapter.onWrite(
                                                arrayOf(PageRange.ALL_PAGES), fd, null,
                                                object : PrintDocumentAdapter.WriteResultCallback() {
                                                    override fun onWriteFinished(pages: Array<PageRange>) {
                                                        fd.close()
                                                        if (!resultSent) {
                                                            resultSent = true
                                                            cleanup()
                                                            result.success(outputFile.absolutePath)
                                                        }
                                                    }
                                                    override fun onWriteFailed(error: CharSequence?) {
                                                        fd.close()
                                                        sendError("WRITE_FAILED", error?.toString() ?: "Write failed")
                                                    }
                                                }
                                            )
                                        } catch (e: Exception) {
                                            sendError("FD_ERROR", e.message ?: "File error")
                                        }
                                    }
                                    override fun onLayoutFailed(error: CharSequence?) {
                                        sendError("LAYOUT_FAILED", error?.toString() ?: "Layout failed")
                                    }
                                }, null
                            )
                        } catch (e: Exception) {
                            sendError("PDF_ERROR", e.message ?: "Unknown error")
                        }
                    }, 2000)
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
