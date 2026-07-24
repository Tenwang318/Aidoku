//
//  AppLockManager.swift
//  Aidoku
//
//  应用锁 — Touch ID / Face ID / 密码验证
//

import UIKit
import LocalAuthentication

class AppLockManager {

    static let shared = AppLockManager()

    private var unlocked = false
    private var authenticating = false
    private var lockWindow: UIWindow?

    private init() {}

    /// 重置锁定状态（进入后台时调用）
    func reset() {
        unlocked = false
    }

    /// 检查并弹出认证
    func checkLock() {
        guard !unlocked, !authenticating else { return }
        authenticating = true

        showLockOverlay()

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
                        self.hideLockOverlay()
                    } else {
                        let laError = authError as? LAError
                        if laError?.code == .userCancel || laError?.code == .systemCancel {
                            // 用户取消 → 保持锁屏，可手动重试
                        } else {
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
            hideLockOverlay()
        }
    }

    @objc func retryAuthentication() {
        checkLock()
    }
}

// MARK: - 锁屏 UI
extension AppLockManager {

    private func showLockOverlay() {
        guard lockWindow == nil else { return }

        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first

        guard let scene = windowScene else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .normal + 1

        let coverVC = UIViewController()
        coverVC.view.backgroundColor = .clear

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        blurView.frame = coverVC.view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coverVC.view.addSubview(blurView)

        let iconView = UIImageView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        iconView.center = CGPoint(x: coverVC.view.center.x, y: coverVC.view.center.y - 120)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemBlue
        iconView.layer.cornerRadius = 20
        iconView.clipsToBounds = true
        if #available(iOS 13.0, *) {
            iconView.image = UIImage(systemName: "lock.shield.fill")
        }
        iconView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin,
                                      .flexibleTopMargin, .flexibleBottomMargin]
        coverVC.view.addSubview(iconView)

        let titleLabel = UILabel(frame: CGRect(x: 30, y: 0, width: coverVC.view.bounds.width - 60, height: 40))
        titleLabel.center = CGPoint(x: coverVC.view.center.x, y: coverVC.view.center.y - 40)
        titleLabel.text = "应用已锁定"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin]
        coverVC.view.addSubview(titleLabel)

        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 220, height: 56)
        button.center = CGPoint(x: coverVC.view.center.x, y: coverVC.view.center.y + 60)
        button.setTitle("Touch ID / Face ID 解锁", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 18)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 28
        button.clipsToBounds = true
        button.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin,
                                    .flexibleTopMargin, .flexibleBottomMargin]
        button.addTarget(AppLockManager.shared, action: #selector(retryAuthentication), for: .touchUpInside)
        coverVC.view.addSubview(button)

        window.rootViewController = coverVC
        window.isHidden = false

        lockWindow = window
    }

    private func hideLockOverlay() {
        lockWindow?.isHidden = true
        lockWindow = nil
    }
}
