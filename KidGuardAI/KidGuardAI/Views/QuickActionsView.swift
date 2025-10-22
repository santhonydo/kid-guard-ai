import SwiftUI
import KidGuardCore

struct QuickActionsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var ruleText = ""
    @State private var isSubmitting = false
    @State private var showCheckmark = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                // Text Field
                TextField("Add rule (e.g., 'Block violent content')", text: $ruleText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isTextFieldFocused ? Color.blue : Color(.separatorColor), lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                    .disabled(isSubmitting)
                    .onSubmit {
                        submitRule()
                    }

                // Add Button with Animation States
                Button(action: submitRule) {
                    AnimatedAddButton(
                        isSubmitting: isSubmitting,
                        showCheckmark: showCheckmark
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(ruleText.isEmpty || isSubmitting)
                .frame(width: 32, height: 32)

                // Voice Button
                Button(action: startVoiceInput) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
    }

    private func submitRule() {
        guard !ruleText.isEmpty, !isSubmitting else { return }

        isSubmitting = true

        Task {
            await coordinator.addRule(from: ruleText)

            await MainActor.run {
                isSubmitting = false
                showCheckmark = true

                // Show checkmark for 1 second, then reset
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showCheckmark = false
                    ruleText = ""
                }
            }
        }
    }

    private func startVoiceInput() {
        coordinator.startVoiceInput()
    }
}

struct AnimatedAddButton: View {
    let isSubmitting: Bool
    let showCheckmark: Bool

    var body: some View {
        ZStack {
            if showCheckmark {
                // Green Checkmark State
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color.green)
                    .cornerRadius(6)
                    .transition(.scale.combined(with: .opacity))
            } else if isSubmitting {
                // Loading Spinner State
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(6)
                    .transition(.opacity)
            } else {
                // Normal Add Button State
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .cornerRadius(6)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSubmitting)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCheckmark)
    }
}

#Preview {
    QuickActionsView()
        .environmentObject(AppCoordinator())
        .frame(width: 400)
}
