import Foundation

extension String {
    /// Converts this String to a byte representation.
    func convertedToData() -> Data { return Data(utf8) }
}
