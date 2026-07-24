//
//  SceneDelegate.swift
//  Aidoku (iOS)
//
//  Created by Skitty on 12/29/21.
//

import UIKit
import LocalAuthentication

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private static let bannerHeight: CGFloat = 30

    var window: UIWindow?
    private var incognitoBannerView: UIView?

    var totalBannerHeight: CGFloat {
        incognitoBannerView?.frame.height ?? 0
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = TabBarController()
            window.tintColor = .systemPink

            if UserDefaults.standard.bool(forKey: "General.useSystemAppearance") {
                window.overrideUserInterfaceStyle = .unspecified
            } else {
                if UserDefaults.standard.integer(forKey: "General.appearance") == 0 {
                    window.overrideUserInterfaceStyle = .light
                } else {
                    window.overrideUserInterfaceStyle = .dark
                }
            }

            self.window = window
            window.makeKeyAndVisible()

            let incognitoBannerView = IncognitoBannerView()
            self.incognitoBannerView = incognitoBannerView
            incognitoBannerView.translatesAutoresizingMaskIntoConstraints = false
            window.insertSubview(incognitoBannerView, at: 0)

            NSLayoutConstraint.activate([
                incognitoBannerView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                incognitoBannerView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                incognitoBannerView.topAnchor.constraint(equalTo: window.topAnchor),
                incognitoBannerView.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: Self.bannerHeight)
            ])
        }

        if
            let url = connectionOptions.urlContexts.first?.url,
            let delegate = UIApplication.shared.delegate as? AppDelegate
        {
            delegate.handleUrl(url: url)
        }
    }

    let contentHideView: UIView = {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .systemBackground
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()

    func sceneWillEnterForeground(_ scene: UIScene) {
        contentHideView.removeFromSuperview()
        AppLockManager.shared.checkLock()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        contentHideView.removeFromSuperview()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AppLockManager.shared.reset()

        let incognitoEnabled = UserDefaults.standard.bool(forKey: "General.incognitoMode")
        if incognitoEnabled {
            (scene as? UIWindowScene)?.windows.first?.addSubview(contentHideView)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url, let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.handleUrl(url: url)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: any UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        let newOrientation = if #available(iOS 16.0, *) {
            windowScene.effectiveGeometry.interfaceOrientation
        } else {
            windowScene.interfaceOrientation
        }
        guard newOrientation != previousInterfaceOrientation else { return }
        NotificationCenter.default.post(name: .orientationDidChange, object: newOrientation)
    }
}

// MARK: - 应用锁（直接弹系统认证，无自定义界面）
class AppLockManager {

    static let shared = AppLockManager()

    private var unlocked = false
    private var authenticating = false

    private init() {}

    func reset() {
        unlocked = false
    }

    func checkLock() {
        guard !unlocked, !authenticating else { return }
        authenticating = true

        let context = LAContext()
        context.localizedCancelTitle = "取消"
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication,
                                   localizedReason: "解锁后才能使用此应用") { [weak self] success, authError in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.authenticating = false
                    if success {
                        self.unlocked = true
                    } else {
                        let laError = authError as? LAError
                        if laError?.code == .userCancel || laError?.code == .systemCancel {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.checkLock()
                            }
                        }
                    }
                }
            }
        } else {
            authenticating = false
            unlocked = true
        }
    }
}
