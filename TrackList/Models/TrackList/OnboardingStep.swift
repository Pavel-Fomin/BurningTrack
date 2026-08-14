//
//  OnboardingStep.swift
//  TrackList
//
//  Содержит данные одного шага onboarding-последовательности.
//
//  Created by Pavel Fomin on 23.05.2025.
//

import Foundation

struct OnboardingStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}
