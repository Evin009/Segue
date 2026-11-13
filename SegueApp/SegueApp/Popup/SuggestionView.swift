import SwiftUI

struct SuggestionView: View {
    let controller: PopupController

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if controller.items.isEmpty {
                Text("No suggestions yet. Segue is still learning.")
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            ForEach(Array(controller.items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(nsImage: item.icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                    Text(item.name)
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    index == controller.selected ? Color.accentColor.opacity(0.25) : .clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
                .onTapGesture { controller.accept(index) }
            }
        }
        .padding(8)
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
