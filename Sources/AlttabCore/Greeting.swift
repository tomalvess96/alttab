public enum Greeting {
    public static func text(hour: Int) -> String {
        switch hour {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }
}
