import Foundation

/// A concrete piece sitting in the tray: a shape plus the color it will paint.
struct Piece: Codable, Equatable, Identifiable {
    let id: UUID
    let shape: ShapeTemplate
    let colorIndex: Int

    init(id: UUID = UUID(), shape: ShapeTemplate, colorIndex: Int) {
        self.id = id
        self.shape = shape
        self.colorIndex = colorIndex
    }

    var cellCount: Int { shape.cellCount }
}
