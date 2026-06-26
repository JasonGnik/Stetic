import SwiftUI

extension View {
    // Adds a "Done" bar above the keyboard that dismisses it. Works for numberPad/decimalPad
    // (which have no return key), so weight/reps/macro entry can always be closed.
    func keyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(.system(size: 15, weight: .semibold))
                .tint(Theme.acc)
            }
        }
    }
}
