//
//  NotificationViewController.swift
//  MyUniDayNotificationContent
//
//  Custom UNNotificationContentExtension hosting the MyUniDay rich assessment notification interface.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import SwiftUI

public class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var hostingController: UIHostingController<NotificationContentView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        #if DEBUG
        print("[NotificationExtension] viewDidLoad called")
        #endif

        preferredContentSize = CGSize(width: 0, height: 220)

        // Pre-install placeholder SwiftUI hosting controller so the view hierarchy is never empty or blank.
        installHostingController(with: .placeholder)
    }

    public func didReceive(_ notification: UNNotification) {
        #if DEBUG
        print("[NotificationExtension] didReceive called")
        print("[NotificationExtension] category = \(notification.request.content.categoryIdentifier)")
        print("[NotificationExtension] userInfo keys = \(Array(notification.request.content.userInfo.keys))")
        #endif

        let userInfo = notification.request.content.userInfo
        let payload = AssessmentReminderPayload(userInfo: userInfo)

        #if DEBUG
        print("[NotificationExtension] parsed title = \(payload.assessmentTitle)")
        print("[NotificationExtension] parsed subject = \(payload.subjectCode)")
        print("[NotificationExtension] parsed progress = \(payload.formattedProgress)")
        #endif

        updateContent(with: payload)
    }

    private func updateContent(with payload: AssessmentReminderPayload) {
        let updateBlock = { [weak self] in
            guard let self = self else { return }
            if let host = self.hostingController {
                host.rootView = NotificationContentView(payload: payload)
            } else {
                self.installHostingController(with: payload)
            }
        }

        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }

    private func installHostingController(with payload: AssessmentReminderPayload) {
        let host = UIHostingController(rootView: NotificationContentView(payload: payload))
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        host.didMove(toParent: self)
        self.hostingController = host

        #if DEBUG
        print("[NotificationExtension] hosting view installed")
        #endif
    }
}
