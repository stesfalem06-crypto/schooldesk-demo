import AppKit
import CoreGraphics
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count >= 2 else {
  fputs("usage: mac_ui.swift ocr <png> | click <word>\n", stderr)
  exit(2)
}

struct Win {
  let id: CGWindowID
  let x: CGFloat
  let y: CGFloat
  let w: CGFloat
  let h: CGFloat
}

func number(_ value: Any?) -> CGFloat {
  if let n = value as? NSNumber { return CGFloat(truncating: n) }
  return 0
}

func schoolWindow() -> Win? {
  let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
  for item in info {
    let owner = (item[kCGWindowOwnerName as String] as? String) ?? ""
    if !owner.lowercased().contains("school") { continue }
    let bounds = item[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let id = item[kCGWindowNumber as String] as? NSNumber
    return Win(
      id: CGWindowID(id?.uint32Value ?? 0),
      x: number(bounds["X"]),
      y: number(bounds["Y"]),
      w: number(bounds["Width"]),
      h: number(bounds["Height"])
    )
  }
  return nil
}

func observations(_ path: String) throws -> [VNRecognizedTextObservation] {
  let request = VNRecognizeTextRequest()
  request.recognitionLevel = .accurate
  let handler = VNImageRequestHandler(url: URL(fileURLWithPath: path), options: [:])
  try handler.perform([request])
  return request.results ?? []
}

switch args[1] {
case "ocr":
  let found = try observations(args[2])
  for obs in found {
    if let text = obs.topCandidates(1).first?.string {
      print(text)
    }
  }
case "click":
  let word = args[2]
  guard let win = schoolWindow() else {
    fputs("window not found\n", stderr)
    exit(1)
  }
  let tmp = NSTemporaryDirectory() + "schooldesk-click.png"
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
  task.arguments = ["-x", "-l", String(win.id), tmp]
  try task.run()
  task.waitUntilExit()
  let found = try observations(tmp)
  guard let obs = found.first(where: { $0.topCandidates(1).first?.string == word }) ?? found.first(where: { ($0.topCandidates(1).first?.string ?? "").contains(word) }) else {
    fputs("could not find \(word)\n", stderr)
    exit(1)
  }
  let box = obs.boundingBox
  let localX = box.midX * win.w
  let localFromTop = (1 - box.midY) * win.h
  let screenH = NSScreen.screens.map { $0.frame.maxY }.max() ?? win.h
  let point = CGPoint(x: win.x + localX, y: screenH - (win.y + localFromTop))
  let source = CGEventSource(stateID: .hidSystemState)
  CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
  CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
default:
  fputs("unknown command\n", stderr)
  exit(2)
}
