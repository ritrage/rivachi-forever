import AVFoundation
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("usage: extract_video_frames.swift <video> <output-dir> <count>\n", stderr)
    exit(1)
}

let videoURL = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2], isDirectory: true)
let count = max(1, Int(args[3]) ?? 6)

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let asset = AVURLAsset(url: videoURL)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 1080, height: 1920)

let durationSeconds = CMTimeGetSeconds(asset.duration)
let times: [NSValue] = (0..<count).map { idx in
    let fraction = Double(idx + 1) / Double(count + 1)
    let seconds = durationSeconds * fraction
    return NSValue(time: CMTime(seconds: seconds, preferredTimescale: 600))
}

var frameIndex = 0
generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, actualTime, result, error in
    if let image {
        frameIndex += 1
        let nsImage = NSImage(cgImage: image, size: .zero)
        guard
            let tiff = nsImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else { return }
        let fileURL = outputDir.appendingPathComponent(String(format: "frame-%02d.png", frameIndex))
        try? png.write(to: fileURL)
        print(fileURL.path)
    } else if let error {
        fputs("error at \(CMTimeGetSeconds(requestedTime)): \(error.localizedDescription)\n", stderr)
    }

    if requestedTime == times.last?.timeValue {
        CFRunLoopStop(CFRunLoopGetMain())
    }
}

CFRunLoopRun()
