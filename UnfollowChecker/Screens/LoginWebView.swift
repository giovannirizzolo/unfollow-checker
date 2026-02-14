//
//  LoginWebView.swift
//  UnfollowChecker
//

internal import SwiftUI
import UIKit
import WebKit

struct LoginWebView: UIViewControllerRepresentable {
    var onSuccess: () -> Void

    func makeUIViewController(context: Context) -> LoginWebViewController {
        LoginWebViewController(onSuccess: onSuccess)
    }

    func updateUIViewController(_ uiViewController: LoginWebViewController, context: Context) {}
}

final class LoginWebViewController: UIViewController, WKNavigationDelegate {

    var onSuccess: () -> Void
    private var webView: WKWebView!
    private var didCapture = false

    init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        webView.load(URLRequest(url: URL(string: "https://www.instagram.com/accounts/login/")!))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didCapture,
              let url   = webView.url,
              let host  = url.host,
              host.contains("instagram.com"),
              !url.path.contains("login"),
              !url.path.contains("challenge")
        else { return }

        extractAndSaveCookies()
    }

    // MARK: - Cookie Capture

    private func extractAndSaveCookies() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }

            let igCookies = cookies.filter { $0.domain.contains("instagram.com") }
            var captured: [KeychainKey: String] = [:]

            for cookie in igCookies {
                switch cookie.name {
                case "sessionid":  captured[.sessionId] = cookie.value
                case "csrftoken":  captured[.csrfToken] = cookie.value
                case "ds_user_id": captured[.userId]    = cookie.value
                case "ig_did":     captured[.igDid]     = cookie.value
                case "mid":        captured[.mid]        = cookie.value
                case "rur":        captured[.rur]        = cookie.value
                default:           break
                }
            }

            // Require at minimum a session ID and CSRF token
            guard captured[.sessionId] != nil, captured[.csrfToken] != nil else { return }

            self.didCapture = true
            for (key, value) in captured {
                try? KeychainService.save(value, for: key)
            }

            DispatchQueue.main.async { self.onSuccess() }
        }
    }
}
