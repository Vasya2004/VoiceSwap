import Foundation
import AppKit
// Inspect alpha bounds, independent of the moving waveform inside the capsule.
let directory = CommandLine.arguments.dropFirst().first ?? ""
guard !directory.isEmpty else { fatalError("Usage: swift scripts/check-hud.swift <export-directory>") }
let files = try FileManager.default.contentsOfDirectory(atPath: directory).filter { $0.hasSuffix(".png") }.sorted()
precondition(files.count > 100, "Missing animation frames")
var sizes: [(Int, Int)] = []
var centers = Set<String>()
for file in files {
    let bitmap = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: directory).appendingPathComponent(file)))!
    var x0 = bitmap.pixelsWide, y0 = bitmap.pixelsHigh, x1 = 0, y1 = 0
    let bytes = bitmap.bitmapData!
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide where bytes[y * bitmap.bytesPerRow + x * bitmap.samplesPerPixel + 3] > 128 {
            x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x+1); y1 = max(y1, y+1)
        }
    }
    centers.insert("\(x0+x1),\(y0+y1)")
    sizes.append((x1-x0, y1-y0))
}
precondition(centers.count == 1, "HUD center moved: \(centers)")
for i in 1...100 {
    precondition(sizes[i].0 >= sizes[i-1].0 && sizes[i].1 >= sizes[i-1].1, "Opening reversed direction")
}
precondition(sizes.allSatisfy { $0.0 <= sizes[150].0 && $0.1 <= sizes[150].1 }, "HUD overshot final size")
print("PASS \(files.count) HUD frames: fixed center, monotonic opening, no overshoot")
