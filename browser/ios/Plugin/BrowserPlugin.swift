import Foundation
import Capacitor

@objc(CAPBrowserPlugin)
public class CAPBrowserPlugin: CAPPlugin {
    private let implementation = Browser()

    @objc func open(_ call: CAPPluginCall) {
        // validate the URL
        guard let urlString = call.getString("url"), let url = URL(string: urlString) else {
            call.reject("Must provide a valid URL to open")
            return
        }
        // extract the optional parameters
        var tintColor: UIColor?
        if let toolbarColor = call.getString("toolbarColor") {
            tintColor = UIColor.capacitor.color(fromHex: toolbarColor)
        }
        var frontColor: UIColor?
        if let controlColor = call.getString("controlColor") {
            frontColor = UIColor.capacitor.color(fromHex: controlColor)
        }
        let style = self.presentationStyle(for: call.getString("presentationStyle"))
        // prepare for display
        guard implementation.prepare(for: url, withTint: tintColor, withFront: frontColor, modalPresentation: style), let viewController = implementation.viewController else {
            call.reject("Unable to display URL")
            return
        }
        implementation.browserEventDidOccur = { [weak self] (event) in
            self?.notifyListeners(event.listenerEvent, data: nil)
        }
        // display
        DispatchQueue.main.async { [weak self] in
            if style == .popover {
                self?.setCenteredPopover(viewController)
            }
            self?.bridge?.presentVC(viewController, animated: true, completion: {
                call.resolve()
            })
        }
    }

    @objc func close(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            if self?.implementation.viewController != nil {
                self?.bridge?.dismissVC(animated: true) {
                    call.resolve()
                    self?.implementation.cleanup()
                }
            } else {
                call.reject("No active window to close!")
            }
        }
    }

    private func presentationStyle(for style: String?) -> UIModalPresentationStyle {
        if let style = style, style == "popover", supportsPopover() {
            return .popover
        }
        return .fullScreen
    }
}

private extension BrowserEvent {
    var listenerEvent: String {
        switch self {
        case .loaded:
            return "browserPageLoaded"
        case .finished:
            return "browserFinished"
        }
    }
}
