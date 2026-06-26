import SwiftUI

// Daily motivation from figures who built their lives on discipline — fits the
// stoic / self-mastery spirit of the niche. One per day, stable across the day.
struct Quote { let text: String; let who: String }

enum Quotes {
    static let all: [Quote] = [
        .init(text: "The impediment to action advances action. What stands in the way becomes the way.", who: "Marcus Aurelius"),
        .init(text: "We suffer more often in imagination than in reality.", who: "Seneca"),
        .init(text: "First say to yourself what you would be; then do what you have to do.", who: "Epictetus"),
        .init(text: "He who has a why to live can bear almost any how.", who: "Friedrich Nietzsche"),
        .init(text: "Discipline is the bridge between goals and accomplishment.", who: "Jim Rohn"),
        .init(text: "The successful warrior is the average man, with laser-like focus.", who: "Bruce Lee"),
        .init(text: "Knowing is not enough; we must apply. Willing is not enough; we must do.", who: "Bruce Lee"),
        .init(text: "Strength does not come from physical capacity. It comes from an indomitable will.", who: "Mahatma Gandhi"),
        .init(text: "It is not death a man should fear, but never beginning to live.", who: "Marcus Aurelius"),
        .init(text: "Take care of your body. It's the only place you have to live.", who: "Jim Rohn"),
        .init(text: "What we achieve inwardly will change outer reality.", who: "Plutarch"),
        .init(text: "No man has the right to be an amateur in the matter of physical training.", who: "Socrates"),
    ]

    // Same quote all day; rotates daily.
    static var today: Quote {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return all[day % all.count]
    }
}

struct DailyQuoteCard: View {
    private let quote = Quotes.today
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "quote.opening").font(.system(size: 16)).foregroundStyle(Theme.acc.opacity(0.7))
            Text(quote.text).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(3)
            Text("— \(quote.who)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.mut)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
    }
}
