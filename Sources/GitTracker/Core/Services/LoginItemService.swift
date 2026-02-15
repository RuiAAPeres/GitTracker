import Foundation
import ServiceManagement

protocol LoginItemManaging: Sendable {
    var supportsConfiguration: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct LoginItemService: LoginItemManaging {
    var supportsConfiguration: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func setEnabled(_ enabled: Bool) throws {
        guard supportsConfiguration else {
            return
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
