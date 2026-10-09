// Original CaptureLine artwork; no upstream Tendedero icon is used.
import AppKit
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.12, green: 0.25, blue: 0.45, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 200, yRadius: 200).fill()
NSColor.white.setStroke()
let line = NSBezierPath()
line.move(to: NSPoint(x: 170, y: 720)); line.line(to: NSPoint(x: 854, y: 720))
line.lineWidth = 24; line.stroke()
NSColor(calibratedRed: 0.3, green: 0.75, blue: 0.78, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 240, y: 250, width: 544, height: 400), xRadius: 44, yRadius: 44).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 482, y: 610, width: 60, height: 160), xRadius: 16, yRadius: 16).fill()
let play = NSBezierPath()
play.move(to: NSPoint(x: 445, y: 335)); play.line(to: NSPoint(x: 445, y: 565)); play.line(to: NSPoint(x: 635, y: 450)); play.close(); play.fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
