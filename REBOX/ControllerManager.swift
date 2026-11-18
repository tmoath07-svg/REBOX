import Foundation
import GameController
import Combine

@MainActor
final class ControllerManager: ObservableObject {
    @Published private(set) var controllerName: String?
    @Published private(set) var isConnected = false
    @Published private(set) var lastInput = "بانتظار يد التحكم"
    @Published private(set) var leftX = 0.0
    @Published private(set) var leftY = 0.0
    @Published private(set) var rightX = 0.0
    @Published private(set) var rightY = 0.0
    @Published private(set) var leftTrigger = 0.0
    @Published private(set) var rightTrigger = 0.0

    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            MainActor.assumeIsolated {
                self?.attach(controller)
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshControllers()
            }
        })
        refreshControllers()
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }


    func refreshControllers() {
        if let controller = GCController.controllers().first {
            attach(controller)
        } else {
            isConnected = false
            controllerName = nil
            lastInput = "بانتظار يد التحكم"
        }
    }

    private func attach(_ controller: GCController) {
        controllerName = controller.vendorName ?? "Game Controller"
        isConnected = true
        controller.extendedGamepad?.valueChangedHandler = { [weak self] _, element in
            Task { @MainActor in self?.lastInput = element.localizedName ?? "تم رصد إدخال" }
        }
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                self?.leftX = Double(x)
                self?.leftY = Double(y)
            }
        }
        controller.extendedGamepad?.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                self?.rightX = Double(x)
                self?.rightY = Double(y)
            }
        }
        controller.extendedGamepad?.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in self?.leftTrigger = Double(value) }
        }
        controller.extendedGamepad?.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in self?.rightTrigger = Double(value) }
        }
    }
}
