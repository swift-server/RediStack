import Foundation

extension String {
    /// Converts this String to a byte representation.
    var bytes: [UInt8] { return .init(self.utf8) }
}
