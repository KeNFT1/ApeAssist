import AmbientContext

let permissions = AmbientPermissions.currentStatus()
print("Accessibility trusted: \(permissions.accessibilityTrusted)")
print("Screen Recording granted: \(permissions.screenRecordingGranted)")

let active = ActiveWindowService().currentActiveWindow()
print("Frontmost app: \(active.appName ?? "unknown")")
print("Bundle id: \(active.bundleIdentifier ?? "unknown")")
print("Window title: \(active.windowTitle ?? "unavailable")")
print("\nDemo does not read clipboard, selected text, or screenshots. Those require explicit UI actions.")
