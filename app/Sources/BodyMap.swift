import SwiftUI

// A small stylized body diagram that highlights one muscle group.
struct BodyMap: View {
    let group: String
    var tint: Color = Theme.acc

    private var active: Set<String> {
        switch group.lowercased() {
        case "chest":     return ["chest"]
        case "abs":       return ["abs"]
        case "back":      return ["chest", "abs"]   // front view — tint the torso
        case "shoulders": return ["shoulders"]
        case "arms":      return ["arms"]
        case "legs":      return ["legs"]
        default:          return []
        }
    }
    private func c(_ part: String) -> Color { active.contains(part) ? tint : Theme.line }

    var body: some View {
        ZStack {
            Circle().fill(Theme.line).frame(width: 10, height: 10).offset(y: -26)
            Capsule().fill(c("arms")).frame(width: 6, height: 24).offset(x: -15, y: -2)
            Capsule().fill(c("arms")).frame(width: 6, height: 24).offset(x: 15, y: -2)
            Capsule().fill(c("shoulders")).frame(width: 28, height: 8).offset(y: -17)
            RoundedRectangle(cornerRadius: 4).fill(c("chest")).frame(width: 22, height: 13).offset(y: -6)
            RoundedRectangle(cornerRadius: 4).fill(c("abs")).frame(width: 18, height: 11).offset(y: 7)
            Capsule().fill(c("legs")).frame(width: 8, height: 18).offset(x: -5, y: 23)
            Capsule().fill(c("legs")).frame(width: 8, height: 18).offset(x: 5, y: 23)
        }
        .frame(width: 40, height: 64)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(["chest", "shoulders", "arms", "legs", "abs"], id: \.self) {
            BodyMap(group: $0)
        }
    }
    .padding().background(Theme.bg).preferredColorScheme(.dark)
}
