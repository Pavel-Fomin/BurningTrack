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
    let image: UIImage      /// Обложка трека
    let isActive: Bool      /// Флаг: это активный трек?
    let isPlaying: Bool     /// Флаг: идёт ли воспроизведение
    var size: CGFloat = 48  /// Размер обложки в pt
    var rpm: Double = 10    /// Скорость вращения (оборотов в минуту)

// MARK: -  UIView фиксированного размера с правильным intrinsicSize
    final class FixedSizeView: UIView {
        let fixedSize: CGFloat
        init(size: CGFloat) {
        self.fixedSize = size
        super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }
        
        /// Сообщаем автолэйауту фиксированный intrinsic размер
        override var intrinsicContentSize: CGSize { CGSize(width: fixedSize, height: fixedSize) }
    }

// MARK: -  Координатор для хранения imageView и состояния активности
    
    final class Coordinator {
        let imageView = UIImageView()
        var wasActive = false   /// Был ли элемент активным на прошлом апдейте
        var wasPlaying = false  /// Было ли воспроизведение на прошлом апдейте
    }
    
    // Создаём координатор
    func makeCoordinator() -> Coordinator { Coordinator() }

    // Создание UIView (контейнер + imageView)
    func makeUIView(context: Context) -> FixedSizeView {
        let container = FixedSizeView(size: size)  /// Контейнер фиксированного размера
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        container.layer.cornerRadius = size / 2    /// Делаем круг
        container.layer.masksToBounds = true
        container.layer.allowsEdgeAntialiasing = true  /// Сглаживание краёв

        let iv = context.coordinator.imageView
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill  /// Заполнение без искажений
        iv.clipsToBounds = true
        iv.layer.allowsEdgeAntialiasing = true

        container.addSubview(iv) /// Добавляем imageView в контейнер и пинним по краям
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

    // Обновление UIView при изменении состояния
    func updateUIView(_ container: FixedSizeView, context: Context) {
        let iv = context.coordinator.imageView
        iv.image = image                        /// Устанавливаем обложку
        container.layer.cornerRadius = size / 2 /// Обновляем радиус (на случай изменения размера)

        let wasActive = context.coordinator.wasActive /// Сохраняем прошлое состояние активности


        if isActive {
            if isPlaying {
                resumeRotation(layer: iv.layer)  /// Продолжаем вращение
                ensureSpin(on: iv.layer)         /// Если нет анимации — создаём
            } else {
                pauseRotation(layer: iv.layer)   /// на паузе угол сохраняем
            }
        } else {
            
            if wasActive {  /// Плавный «возврат к нулю», только когда мы СТАЛИ неактивными
                smoothReturnToZero(layer: iv.layer, duration: 1)
            } else {
                stopRotation(layer: iv.layer) /// на всякий случай: чистый неактивный
            }
        }

        /// Обновляем историю состояния
        context.coordinator.wasActive = isActive
        context.coordinator.wasPlaying = isPlaying
    }

    
// MARK: - CAAnimation

    private var spinKey: String { "rotating.artwork.spin" }

    // Запуск постоянного вращения (если ещё не запущено)
    private func ensureSpin(on layer: CALayer) {
        if layer.animation(forKey: spinKey) == nil {
            let a = CABasicAnimation(keyPath: "transform.rotation.z")
            a.fromValue = 0
            a.toValue = 2 * Double.pi
            a.duration = 60.0 / max(rpm, 0.1) /// Длительность одного оборота
            a.repeatCount = .infinity
            a.isRemovedOnCompletion = false
            a.fillMode = .forwards
            a.timingFunction = CAMediaTimingFunction(name: .linear)
            layer.add(a, forKey: spinKey)
        }
        if layer.speed == 0 { resumeRotation(layer: layer) } /// Возобновляем при необходимости
    }

    // Пауза вращения с фиксацией текущего угла
    private func pauseRotation(layer: CALayer) {
        guard layer.speed != 0 else { return }
        let t = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = t
    }

    // Возобновление вращения с сохранённого угла
    private func resumeRotation(layer: CALayer) {
        guard layer.speed == 0 else { return }
        let paused = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        let since = layer.convertTime(CACurrentMediaTime(), from: nil) - paused
        layer.beginTime = since
    }

    // Полная остановка вращения
    private func stopRotation(layer: CALayer) {
        layer.removeAnimation(forKey: spinKey)
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
    }
    
    // Плавный возврат к нулю (0°) после остановки
    private func smoothReturnToZero(layer: CALayer, duration: CFTimeInterval) {
        let currentAngle = (layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0 // Текущий угол из presentationLayer (если нет — считаем, что 0)

        // Останавливаем постоянное вращение, оставляя фактический угол в модельном слое
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: spinKey)  /// Убираем постоянное вращение
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        layer.setValue(currentAngle, forKeyPath: "transform.rotation.z") /// Фиксируем текущий угол
        CATransaction.commit()

        let anim = CABasicAnimation(keyPath: "transform.rotation.z")  /// Анимация докрутки до ближайшего нуля
        anim.fromValue = currentAngle
        let twoPi = 2 * CGFloat.pi
        let target = CGFloat(ceil(currentAngle / twoPi)) * twoPi  /// Ближайший кратный 2π
        anim.toValue = target
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            CATransaction.begin()  /// Зафиксировать идеальный ноль и очистить хвосты
            CATransaction.setDisableActions(true)
            layer.removeAnimation(forKey: "rotating.artwork.reset")
            layer.setAffineTransform(.identity)  /// Зафиксировать ровный ноль
            CATransaction.commit()
        }
        
        layer.add(anim, forKey: "rotating.artwork.reset")
        CATransaction.commit()
    }
}
