//
//  ArgusOnboardingView.swift
//  argus
//
//  Created by Argus Team on 05.02.2026.
//

import SwiftUI

struct ArgusOnboardingView: View {
    let onFinished: () -> Void

    @State private var index: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Argus, karar vermeyi öğretir.",
            body: "Alım-satımda nelere bakılır, hangi sırayla düşünülür, hangi sinyaller birlikte okunur. Argus bunları adım adım gösterir.",
            footer: "Amaç, \"ne yapman gerektiğini\" değil, nasıl düşünmen gerektiğini öğretmektir."
        ),
        OnboardingPage(
            title: "Argus yatırım tavsiyesi vermez.",
            body: "Burada \"şunu al, bunu sat\" gibi yönlendirme yoktur. Argus yalnızca düşünme sürecini örnekler.",
            footer: "Karar ve sorumluluk tamamen kullanıcıya aittir."
        ),
        OnboardingPage(
            title: "Veriler kusursuz değildir.",
            body: "Argus, çoğu zaman ücretsiz ve tutarsız kaynaklardan beslenebilir. Bu yüzden sonuçlar kesinlik içermez.",
            footer: "Argus'un amacı doğruluk değil, mantığı kavratmaktır."
        ),
        OnboardingPage(
            title: "Argus risk aldırmaz.",
            body: "Gerçek para ile işlem kararları Argus'a bırakılmaz. Argus yalnızca eğitim için bir simülasyon zihniyeti sunar.",
            footer: "Deneyim ve sorumluluk sende; Argus sadece bir öğrenme aracıdır."
        ),
        OnboardingPage(
            title: "Argus böyle kullanılmalı",
            body: "Bir senaryo seç, işaretleri sırayla oku, ardından \"ben olsam ne yapardım?\" diye düşün.",
            footer: "Amaç, tek doğruyu bulmak değil, düşünme kasını geliştirmek."
        ),
        OnboardingPage(
            title: "Kimler için uygun?",
            body: "Piyasayı öğrenmek isteyenler, karar mantığını merak edenler, acele etmeyip düşünmeyi öğrenmek isteyenler.",
            footer: "Hızlı kazanç arayanlar için uygun değildir."
        ),
        OnboardingPage(
            title: "Son bir kez netleştirelim",
            body: "Argus, yatırım kararı verdirmez. Buradaki içerik eğitim amaçlıdır ve kesinlik içermez.",
            footer: "Hazırsan başlayalım."
        )
    ]

    var body: some View {
        ZStack {
            OnboardingBackground()

            VStack(spacing: 0) {
                header

                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { item in
                        OnboardingPageView(page: item.element)
                            .tag(item.offset)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                indicators

                controls
            }
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack {
            Text("ARGUS")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .tracking(6)
            Spacer()
            Text("\(index + 1)/\(pages.count)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private var indicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.cyan : Color.white.opacity(0.2))
                    .frame(width: i == index ? 24 : 8, height: 6)
            }
        }
        .padding(.vertical, 16)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    index = max(0, index - 1)
                }
            } label: {
                Text("Geri")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(index == 0 ? .white.opacity(0.3) : .white)
                    .frame(width: 90, height: 40)
                    .background(Color.white.opacity(index == 0 ? 0.05 : 0.12))
                    .cornerRadius(10)
            }
            .disabled(index == 0)

            Spacer()

            Button {
                if index < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        index += 1
                    }
                } else {
                    onFinished()
                }
            } label: {
                Text(index == pages.count - 1 ? "Başla" : "İleri")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 120, height: 40)
                    .background(Color.cyan)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingPage: Hashable {
    let title: String
    let body: String
    let footer: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 22) {
            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.body)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.footer)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.cyan.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.08, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            OnboardingCyberGrid()
                .opacity(0.2)
        }
    }
}

private struct OnboardingCyberGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 40

                for x in stride(from: 0, to: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                for y in stride(from: 0, to: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.cyan, lineWidth: 0.5)
        }
    }
}

#Preview {
    ArgusOnboardingView(onFinished: {})
}
