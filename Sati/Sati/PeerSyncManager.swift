#if os(macOS) || os(iOS)
import Foundation
import MultipeerConnectivity
import Combine

final class PeerSyncManager: NSObject, ObservableObject {

    private let serviceType = "sati-sync"
    private let peerID: MCPeerID
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var session: MCSession

    private let topicManager: TopicManager
    private let reminderManager: ReminderManager
    private var cancellables = Set<AnyCancellable>()
    private var debounceTimer: Timer?
    private var lastSentHash: Int = 0

    private static let updatedAtKey = "peerSyncUpdatedAt"

    @Published var peerConnected: Bool = false

    var updatedAt: Date {
        get {
            let ts = UserDefaults.standard.double(forKey: Self.updatedAtKey)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : Date.distantPast
        }
        set {
            UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Self.updatedAtKey)
        }
    }

    init(topicManager: TopicManager, reminderManager: ReminderManager) {
        self.topicManager = topicManager
        self.reminderManager = reminderManager

        #if os(macOS)
        let name = Host.current().localizedName ?? "Mac"
        #else
        let name = UIDevice.current.name
        #endif
        self.peerID = MCPeerID(displayName: name)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)

        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()

        topicManager.$topics
            .sink { [weak self] (_: [String]) in self?.localDidChange() }
            .store(in: &cancellables)

        reminderManager.$intervalMinutes
            .sink { [weak self] (_: Int) in self?.localDidChange() }
            .store(in: &cancellables)
    }

    deinit {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    private func localDidChange() {
        updatedAt = Date()
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.broadcastState()
        }
    }

    private func makePayload() -> [String: Any] {
        return [
            "topics": topicManager.topics,
            "topicOffset": topicManager.offset,
            "intervalMinutes": reminderManager.intervalMinutes,
            "updatedAt": updatedAt.timeIntervalSince1970,
        ]
    }

    private func payloadHash(_ payload: [String: Any]) -> Int {
        var hasher = Hasher()
        hasher.combine(payload["topics"] as? [String] ?? [])
        hasher.combine(payload["topicOffset"] as? Int ?? 0)
        hasher.combine(payload["intervalMinutes"] as? Int ?? 5)
        return hasher.finalize()
    }

    private func broadcastState() {
        guard !session.connectedPeers.isEmpty else { return }
        let payload = makePayload()
        let hash = payloadHash(payload)
        lastSentHash = hash
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func applyReceived(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let receivedHash = payloadHash(json)
        if receivedHash == lastSentHash { return }

        let receivedTimestamp = json["updatedAt"] as? Double ?? 0
        let receivedDate = Date(timeIntervalSince1970: receivedTimestamp)
        guard receivedDate > updatedAt else { return }

        if let topics = json["topics"] as? [String] {
            topicManager.topics = topics
        }
        if let offset = json["topicOffset"] as? Int {
            topicManager.setOffset(offset)
        }
        if let interval = json["intervalMinutes"] as? Int {
            reminderManager.intervalMinutes = interval
        }
        updatedAt = receivedDate
    }
}

extension PeerSyncManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.peerConnected = !session.connectedPeers.isEmpty
            if state == .connected {
                self.broadcastState()
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.applyReceived(data)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

extension PeerSyncManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }
}

extension PeerSyncManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
#endif
