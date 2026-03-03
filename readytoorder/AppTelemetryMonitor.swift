import Foundation
import MetricKit

final class AppTelemetryMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = AppTelemetryMonitor()

    private var started = false

    private override init() {
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard !payloads.isEmpty else { return }

        for payload in payloads {
            let crashCount = payload.crashDiagnostics?.count ?? 0
            let hangCount = payload.hangDiagnostics?.count ?? 0
            let cpuCount = payload.cpuExceptionDiagnostics?.count ?? 0
            let diskCount = payload.diskWriteExceptionDiagnostics?.count ?? 0
            let total = crashCount + hangCount + cpuCount + diskCount
            guard total > 0 else { continue }

            let begin = payload.timeStampBegin
            let end = payload.timeStampEnd
            let message = "MetricKit diagnostics: crash=\(crashCount), hang=\(hangCount), cpu=\(cpuCount), disk=\(diskCount), begin=\(begin), end=\(end)"

            Task { @MainActor in
                TasteBackendClient.shared.reportClientEvent(
                    scope: "ios_diagnostic",
                    code: "metrickit_payload",
                    message: message,
                    statusCode: nil,
                    requestID: ""
                )
            }
        }
    }
}
