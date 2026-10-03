import SwiftUI

struct TodoColorOption: Identifiable {
    let id: String
    let color: Color
}

enum TodoPalette {
    static let options: [TodoColorOption] = [
        TodoColorOption(id: "coral", color: Color(red: 1.00, green: 0.42, blue: 0.46)),
        TodoColorOption(id: "mango", color: Color(red: 1.00, green: 0.65, blue: 0.25)),
        TodoColorOption(id: "lemon", color: Color(red: 1.00, green: 0.86, blue: 0.29)),
        TodoColorOption(id: "mint", color: Color(red: 0.36, green: 0.86, blue: 0.59)),
        TodoColorOption(id: "aqua", color: Color(red: 0.27, green: 0.82, blue: 0.82)),
        TodoColorOption(id: "sky", color: Color(red: 0.32, green: 0.68, blue: 1.00)),
        TodoColorOption(id: "lavender", color: Color(red: 0.63, green: 0.50, blue: 1.00)),
        TodoColorOption(id: "berry", color: Color(red: 0.95, green: 0.40, blue: 0.72))
    ]

    static func color(for key: String) -> Color {
        options.first(where: { $0.id == key })?.color ?? options[1].color
    }
}
