import SwiftUI

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.body)
            .foregroundColor(KMTheme.inputText)
            .padding(12)
            .background(KMTheme.inputBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KMTheme.inputBorder, lineWidth: 1)
            )
            .keyboardType(keyboardType)
            .accentColor(KMTheme.accent)
            .onAppear {
                // Configure placeholder text color
                UITextField.appearance().attributedPlaceholder = NSAttributedString(
                    string: placeholder,
                    attributes: [NSAttributedString.Key.foregroundColor: UIColor(KMTheme.inputPlaceholder)]
                )
            }
    }
}

struct ThemedTextField_Previews: PreviewProvider {
    @State static var text = ""
    
    static var previews: some View {
        VStack(spacing: 16) {
            ThemedTextField(placeholder: "Enter text", text: $text)
            ThemedTextField(placeholder: "Enter number", text: $text, keyboardType: .decimalPad)
        }
        .padding()
        .background(KMTheme.background)
        .preferredColorScheme(.dark)
    }
}
