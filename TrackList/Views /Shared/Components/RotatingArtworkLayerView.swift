//
//  RotatingArtworkLayerView.swift
//  TrackList
//
//  Компонент вращения обложки активного трека с плавным докрутом
//
//  Created by Pavel Fomin on 11.08.2025.
//

import SwiftUI
import UIKit

struct RotatingArtworkView: UIViewRepresentable {
    let image: UIImage          // обложка (любой размер)
    let isActive: Bool          // эта ячейка/экран активны?
    let isPlaying: Bool         // сейчас играет?
    var size: CGFloat = 48      // диаметр кружка
    var rpm: Double = 10        // оборотов/мин (обычное вращение)
    var smoothReturnDuration: CFTimeInterval = 1.2 // докрут

// MARK: -  Ключ анимации
    private static let spinKey = "rotating.spin"

// MARK: -  Контейнер фиксированного размера
    
    final class ViewBox: UIView {
        let s: CGFloat
        let img = UIImageView()
        init(size: CGFloat, rounded: UIImage) {
            self.s = size
            super.init(frame: CGRect(origin: .zero, size: .init(width: size, height: size)))
            isOpaque = false
            img.image = rounded
            img.contentMode = .scaleAspectFill
            img.clipsToBounds = false
            img.layer.allowsEdgeAntialiasing = true
            addSubview(img)
        }
        required init?(coder: NSCoder) { fatalError() }
        override var intrinsicContentSize: CGSize { .init(width: s, height: s) }
        override func layoutSubviews() { super.layoutSubviews(); img.frame = bounds.integral }
    }

// MARK: -  Координатор — только нужные флаги
    
    final class Coordinator {
        var wasActive = false
        var wasPlaying = false
        var appActive = true
        weak var cachedSource: CGImage?
        var cachedSize: CGFloat = 0
        var observers: [NSObjectProtocol] = []
    }
    
    
// MARK: -  Создаёт координатор для хранения состояния и подписок на события
    
    func makeCoordinator() -> Coordinator { Coordinator() }

    
// MARK: - UIViewRepresentable
    
    /// Создаёт UIView (ViewBox) с закруглённым изображением и настраивает подписки на события жизненного цикла приложения
    func makeUIView(context: Context) -> ViewBox {
        let rounded = bakeCircle(image, size: size)
        let v = ViewBox(size: size, rounded: rounded)

        // кэш
        context.coordinator.cachedSource = image.cgImage
        context.coordinator.cachedSize   = size

        // Жизненный цикл приложения
        let nc = NotificationCenter.default

        // Уход в неактивное: мгновенно freeze
        let o1 = nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            context.coordinator.appActive = false
            CATransaction.begin(); CATransaction.setDisableActions(true)
            self.ensureSpin(on: v.img.layer)     // гарантируем наличие анимации
            self.pause(layer: v.img.layer)       // и ставим на паузу
            CATransaction.commit()
        }

        // Возврат: заранее подкладываем анимацию (если играло)
        let o2 = nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            if context.coordinator.wasActive && context.coordinator.wasPlaying {
                self.ensureSpin(on: v.img.layer)
            }
        }

        // Стали активны: только resume при игре, иначе — остаёмся замороженными
        let o3 = nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            context.coordinator.appActive = true
            if context.coordinator.wasActive && context.coordinator.wasPlaying {
                self.resume(layer: v.img.layer)
            } else {
                self.pause(layer: v.img.layer)
            }
        }

        context.coordinator.observers = [o1, o2, o3]

        // Первичное состояние
        apply(to: v.img.layer,
              isActive: isActive,
              isPlaying: isPlaying,
              wasActive: false,
              appActive: context.coordinator.appActive)

        context.coordinator.wasActive  = isActive
        context.coordinator.wasPlaying = isPlaying
        return v
    }

    
// MARK: -  Обновляет UIView при изменении входных параметров (isActive, isPlaying, image, size)
    func updateUIView(_ v: ViewBox, context: Context) {
        
        // Перерисовываем bitmap только если реально поменялся
        if context.coordinator.cachedSource !== image.cgImage || context.coordinator.cachedSize != size {
            v.img.image = bakeCircle(image, size: size)
            context.coordinator.cachedSource = image.cgImage
            context.coordinator.cachedSize   = size
        }

        // Обновляем «прошлые» флаги
        let prevActive  = context.coordinator.wasActive
        let prevPlaying = context.coordinator.wasPlaying
        context.coordinator.wasActive  = isActive
        context.coordinator.wasPlaying = isPlaying

        // Если ничего не поменялось — ничего не делаем
        if prevActive == isActive, prevPlaying == isPlaying { return }

        // Применяем новое состояние
        apply(to: v.img.layer,
              isActive: isActive,
              isPlaying: isPlaying,
              wasActive: prevActive,
              appActive: context.coordinator.appActive)
    }

    
// MARK: -   Очищает ресурсы и удаляет подписки при уничтожении UIView
    
    static func dismantleUIView(_ v: ViewBox, coordinator: Coordinator) {
        let nc = NotificationCenter.default
        coordinator.observers.forEach { nc.removeObserver($0) }
        coordinator.observers.removeAll()
        v.img.layer.removeAnimation(forKey: Self.spinKey)
        v.img.layer.speed = 1; v.img.layer.timeOffset = 0; v.img.layer.beginTime = 0
    }

    
// MARK: -  MARK: Логика состояний
    
    /// Применяет новое состояние вращения в зависимости от активности, проигрывания и состояния приложения
    private func apply(to layer: CALayer,
                       isActive: Bool,
                       isPlaying: Bool,
                       wasActive: Bool,
                       appActive: Bool)
    {
        if isActive {
            if isPlaying { resume(layer: layer); ensureSpin(on: layer) }
            else         { pause(layer: layer) }
        } else {
            // Докручиваем только при «реальной» потере активности (не при уходе в фон)
            if wasActive && appActive { smoothReturnForward(layer: layer) }
            else                      { stop(layer: layer) }
        }
    }

    
// MARK: -  Core Animation helpers
    
    /// Гарантирует наличие бесконечной анимации вращения на слое
    private func ensureSpin(on layer: CALayer) {
        if layer.animation(forKey: Self.spinKey) == nil {
            let a = CABasicAnimation(keyPath: "transform.rotation.z")
            a.fromValue = 0
            a.toValue = 2 * Double.pi
            a.duration = 60.0 / max(rpm, 0.1)     // 1 оборот
            a.repeatCount = .infinity
            a.isRemovedOnCompletion = false
            a.fillMode = .forwards
            a.timingFunction = CAMediaTimingFunction(name: .linear)
            layer.add(a, forKey: Self.spinKey)
        }
        if layer.speed == 0 { resume(layer: layer) }
    }

    /// Ставит анимацию вращения на паузу, сохраняя текущий прогресс
    private func pause(layer: CALayer) {
        guard layer.speed != 0 else { return }
        let t = layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = 0
        layer.timeOffset = t
    }

    /// Возобновляет анимацию вращения с места, где она была остановлена
    private func resume(layer: CALayer) {
        guard layer.speed == 0 else { return }
        let paused = layer.timeOffset
        layer.speed = 1
        layer.timeOffset = 0
        layer.beginTime = 0
        layer.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) - paused
    }

    /// Полностью останавливает вращение и удаляет анимацию
    private func stop(layer: CALayer) {
        layer.removeAnimation(forKey: Self.spinKey)
        layer.speed = 1; layer.timeOffset = 0; layer.beginTime = 0
    }

    /// Выполняет плавный докрут до ближайшей кратной 360° позиции
    private func smoothReturnForward(layer: CALayer) {
        let current = (layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0
        let twoPi = 2 * CGFloat.pi
        let target = ceil(current / twoPi) * twoPi

        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey: Self.spinKey)
        layer.setValue(current, forKeyPath: "transform.rotation.z")
        layer.speed = 1; layer.timeOffset = 0; layer.beginTime = 0
        CATransaction.commit()

        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.setValue(target, forKeyPath: "transform.rotation.z")
        CATransaction.commit()

        let a = CABasicAnimation(keyPath: "transform.rotation.z")
        a.fromValue = current
        a.toValue   = target
        a.duration  = smoothReturnDuration   // ← меняй длительность докрута здесь одним параметром
        a.timingFunction = CAMediaTimingFunction(name: .easeOut)
        a.fillMode = .forwards
        a.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            layer.removeAnimation(forKey: "rotating.artwork.reset")
            CATransaction.commit()
        }
        layer.add(a, forKey: "rotating.artwork.reset")
        CATransaction.commit()
    }

// MARK: -  «Запекаем» круг (без cornerRadius/masks)
    
    /// Создаёт круговую обложку из изображения без использования cornerRadius/masks
    private func bakeCircle(_ image: UIImage, size: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = image.scale
        fmt.opaque = false // ← вот здесь ключевое изменение
        return UIGraphicsImageRenderer(size: .init(width: size, height: size), format: fmt).image { _ in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            UIBezierPath(ovalIn: rect).addClip()
            let k = max(size / image.size.width, size / image.size.height)
            let w = image.size.width * k, h = image.size.height * k
            image.draw(in: CGRect(x: (size - w)*0.5, y: (size - h)*0.5, width: w, height: h))
        }
    }
}
