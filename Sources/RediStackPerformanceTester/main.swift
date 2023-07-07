import RediStack
import Foundation
import NIOCore
import NIOEmbedded
import RESP3

func benchmark(label: String = #function, _ n: Int = 100_000, run: () throws -> Void) throws {
    let start = Date()
    for _ in 0..<n {
        try run()
    }
    let end = Date()
    let mode: String

#if DEBUG
    mode = "DEBUG"
#else
    mode = "RELEASE"
#endif

    print("\(label): Test took \(end.timeIntervalSince(start)) seconds on \(mode)")
}

try benchmarkRESPProtocol()
try benchmarkRESP3Protocol()

try benchmarkRESPParsing()
try benchmarkRESP3Parsing()
