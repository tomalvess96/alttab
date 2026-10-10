import AlttabCore
import Foundation
import Observation

@MainActor @Observable
final class WindowStore {
    private(set) var windows: [WindowItem] = []
    private(set) var currentWorkspace = ""
    private(set) var lastError: String?
    /// Chamado quando outra janela ganha foco (usado para atualizar a miniatura dela).
    @ObservationIgnored var onFocusChange: (@MainActor (Int) -> Void)?

    @ObservationIgnored private var mru = MRUTracker()
    @ObservationIgnored private let client: AerospaceClient
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var lastFocused: Int?

    init(client: AerospaceClient = AerospaceClient()) {
        self.client = client
    }

    var mruOrdered: [WindowItem] { mru.sorted(windows) }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                await self?.poll(full: tick % 8 == 0)
                tick += 1
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func refresh() async {
        await poll(full: true)
    }

    func noteFocused(_ id: Int) {
        mru.touch(id)
    }

    private func poll(full: Bool) async {
        let client = self.client
        let result = await Task.detached { () -> Result<(FocusedWindow?, String, [WindowItem]?), Error> in
            Result {
                let focused = try client.focused()
                let workspace = try focused?.workspace ?? client.focusedWorkspace()
                return (focused, workspace, full ? try client.windows() : nil)
            }
        }.value

        switch result {
        case .failure(let error):
            lastError = String(describing: error)
        case .success(let (focused, workspace, list)):
            lastError = nil
            currentWorkspace = workspace
            if let focused {
                mru.touch(focused.id)
                if focused.id != lastFocused {
                    lastFocused = focused.id
                    onFocusChange?(focused.id)
                }
            }
            if let list {
                mru.prune(keeping: Set(list.map(\.id)))
                windows = list
            }
        }
    }
}
