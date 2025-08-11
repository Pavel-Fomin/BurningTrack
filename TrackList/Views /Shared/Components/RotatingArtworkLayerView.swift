//
//  RotatingArtworkLayerView.swift
//  TrackList
//
//  Компонент вращения обложки активного трека
//
//  Created by Pavel Fomin on 11.08.2025.
//

import SwiftUI
import UIKit

struct RotatingArtworkLayerView: UIViewRepresentable {
    let image: UIImage
    let isActive: Bool
    let isPlaying: Bool
    var size: CGFloat = 48
    var rpm: Double = 10 // оборотов/мин

    // Контейнер фиксированного размера с правильным intrinsicSize
    final class FixedSizeView: UIView {
        let fixedSize: CGFloat
        init(size: CGFloat) {
            self.fixedSize = size
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }
        override var intrinsicContentSize: CGSize { CGSize(width: fixedSize, height: fixedSize) }
    }

    final class Coordinator {
        let imageView = UIImageView()
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> FixedSizeView {
        let container = FixedSizeView(size: size)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        container.layer.cornerRadius = size / 2
        container.layer.masksToBounds = true
        container.layer.allowsEdgeAntialiasing = true

        let iv = context.coordinator.imageView
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.allowsEdgeAntialiasing = true

        container.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            iv.topAnchor.constraint(equalTo: container.topAnchor),
            iv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: size),
            container.heightAnchor.constraint(equalToConstant: size)
        ])

        return container
    }

    func updateUIView(_ container: FixedSizeView, context: Context) {
        let iv = context.coordinator.imageView
        iv.image = image
        container.layer.cornerRadius = size / 2

        if isActive {
            if isPlaying {
                resumeRotation(layer: iv.layer)
                ensureSpin(on: iv.layer)
            } else {
                pauseRotation(layer: iv.layer)
            }
        } else {
            stopRotation(layer: iv.layer)
        }
    }

    // MARK: - CAAnimation

    private var spinKey: String { "rotating.artwork.spin" }

    private func ensureSpin(on layer: CALayer) {
        if layer.animation(forKey: spinKey) == nil {
            let a = CABasicAnimation(keyPath: "transform.rotation.z")
            a.fromValue = 0
            a.toValue = 2 * Double.pi
            a.duration = 60.0 / max(rpm, 0.1)
            a.repeatCount = .infinity
            a.isRemovedOnCompletion = false
            a.fillMode = .forwards
            a.timingFunction = CAMediaTimingFunction(name: .linear)
            layer.add(a, forKey: spinKey)
        }
        if layer.speed == 0 { resumeRotation(layer: layer) }
    }

    private func pauseRotation(layer: CALayer) {
        guard layer.speed != 0 else { return }
        let t = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = t
    }

    private func resumeRotation(layer: CALayer) {
        guard layer.speed == 0 else { return }
        let paused = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let since = layer.convertTime(CACurrentMediaTime(), from: nil) - paused
        layer.beginTime = since
    }

    private func stopRotation(layer: CALayer) {
        layer.removeAnimation(forKey: spinKey)
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
    }
}
