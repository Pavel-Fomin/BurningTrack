//
//  Onboarding.swift
//  TrackList
//
//  Created by Pavel Fomin on 23.05.2025.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStepIndex = 0

    let steps: [OnboardingStep]

    var body: some View {
        VStack {
            Spacer()

            Text(steps[currentStepIndex].title)
                .font(.title)
                .bold()
                .padding(.bottom, 8)

            Text(steps[currentStepIndex].description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()

            HStack {
                Button("Пропустить") {
                    isPresented = false
                }
                .padding()

                Spacer()

                Button(currentStepIndex < steps.count - 1 ? "Дальше" : "Готово") {
                    if currentStepIndex < steps.count - 1 {
                        currentStepIndex += 1
                    } else {
                        isPresented = false
                    }
                }
                .padding()
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground).ignoresSafeArea())
        .transition(.slide)
    }
}
