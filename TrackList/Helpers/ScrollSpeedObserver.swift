//
//  ScrollSpeedObserver.swift
//  TrackList
//
//  Created by Pavel Fomin on 09.08.2025.
//

import Foundation
import SwiftUI

struct ScrollSpeedObserver: View {
    @ObservedObject var model: ScrollSpeedModel
    var body: some View {
        _PlatformObserver(model: model).allowsHitTesting(false).opacity(0.0001)
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit

private struct _PlatformObserver: UIViewRepresentable {
    @ObservedObject var model: ScrollSpeedModel

    final class ProxyView: UIView {
        weak var scrollView: UIScrollView?
        var lastTime: CFTimeInterval = CACurrentMediaTime()
        var lastOffsetY: CGFloat = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attach()
        }

        private func attach() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // ищем ближайший UIScrollView вверх по иерархии
                var view: UIView? = self
                while let v = view, !(v is UIScrollView) { view = v.superview }
                guard let sv = view as? UIScrollView else { return }
                self.scrollView = sv
                // KVO на contentOffset
                sv.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset), options: [.initial, .new], context: nil)
                self.lastOffsetY = sv.contentOffset.y
                self.lastTime = CACurrentMediaTime()
            }
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard keyPath == #keyPath(UIScrollView.contentOffset),
                  let sv = scrollView else { return }
            let now = CACurrentMediaTime()
            let dt = max(now - lastTime, 0.001)
            let dy = sv.contentOffset.y - lastOffsetY
            let velocity = abs(dy) / CGFloat(dt) // pt/сек

            // пробрасываем вверх через NotificationCenter (без retain циклов)
            NotificationCenter.default.post(name: ._scrollVelocityDidUpdate, object: nil, userInfo: ["v": velocity])

            lastTime = now
            lastOffsetY = sv.contentOffset.y
        }

        deinit {
            if let sv = scrollView {
                sv.removeObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset))
            }
        }
    }

    func makeUIView(context: Context) -> ProxyView {
        let v = ProxyView()
        NotificationCenter.default.addObserver(forName: ._scrollVelocityDidUpdate, object: nil, queue: .main) { note in
            if let v = note.userInfo?["v"] as? CGFloat {
                model.report(velocityAbs: v)
            }
        }
        return v
    }

    func updateUIView(_ uiView: ProxyView, context: Context) { }
}

#elseif os(macOS)
import AppKit

private struct _PlatformObserver: NSViewRepresentable {
    @ObservedObject var model: ScrollSpeedModel

    final class ProxyView: NSView {
        weak var scrollView: NSScrollView?
        var lastTime: CFTimeInterval = CACurrentMediaTime()
        var lastOffsetY: CGFloat = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attach()
        }

        private func attach() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var v: NSView? = self
                while let cur = v, !(cur is NSScrollView) { v = cur.superview }
                guard let sv = v as? NSScrollView else { return }
                self.scrollView = sv
                sv.contentView.postsBoundsChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(boundsChanged), name: NSView.boundsDidChangeNotification, object: sv.contentView)
                self.lastOffsetY = sv.contentView.bounds.origin.y
                self.lastTime = CACurrentMediaTime()
            }
        }

        @objc private func boundsChanged() {
            guard let sv = scrollView else { return }
            let now = CACurrentMediaTime()
            let dt = max(now - lastTime, 0.001)
            let dy = sv.contentView.bounds.origin.y - lastOffsetY
            let velocity = abs(dy) / CGFloat(dt) // pt/сек
            NotificationCenter.default.post(name: ._scrollVelocityDidUpdate, object: nil, userInfo: ["v": velocity])

            lastTime = now
            lastOffsetY = sv.contentView.bounds.origin.y
        }

        deinit {
            if let sv = scrollView {
                NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: sv.contentView)
            }
        }
    }

    func makeNSView(context: Context) -> ProxyView {
        let v = ProxyView()
        NotificationCenter.default.addObserver(forName: ._scrollVelocityDidUpdate, object: nil, queue: .main) { note in
            if let v = note.userInfo?["v"] as? CGFloat {
                model.report(velocityAbs: v)
            }
        }
        return v
    }

    func updateNSView(_ nsView: ProxyView, context: Context) { }
}
#endif

private extension Notification.Name {
    static let _scrollVelocityDidUpdate = Notification.Name("_scrollVelocityDidUpdate")
}
