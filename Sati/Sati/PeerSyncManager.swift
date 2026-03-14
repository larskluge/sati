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
    @Published var connectedPeerName: String? = nil
    @Published var lastSyncDate: Date? = nil

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

        topicManager.$offset
            .sink { [weak self] (_: Int) in self?.localDidChange() }
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

    private func makePayload() -> SyncPayload {
        SyncPayload(
            topics: topicManager.topics,
            topicOffset: topicManager.offset,
            intervalMinutes: reminderManager.intervalMinutes,
            updatedAt: updatedAt
        )
    }

    private func broadcastState() {
        guard !session.connectedPeers.isEmpty else { return }
        let payload = makePayload()
        lastSentHash = payload.contentHash()
        guard let data = try? JSONSerialization.data(withJSONObject: payload.toDictionary()) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        lastSyncDate = Date()
        SatiLog.info("PeerSync", "broadcast to \(session.connectedPeers.count) peers")
    }

    private func applyReceived(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let received = SyncPayload.fromDictionary(json) else {
            SatiLog.error("PeerSync", "failed to decode received data")
            return
        }

        if received.contentHash() == lastSentHash { return }

        let local = makePayload()
        guard received.shouldReplace(local) else { return }

        topicManager.topics = received.topics
        topicManager.setOffset(received.topicOffset)
        reminderManager.intervalMinutes = received.intervalMinutes
        updatedAt = received.updatedAt
        lastSyncDate = Date()
    }
}

extension PeerSyncManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        SatiLog.info("PeerSync", "peer \(peerID.displayName) state=\(state.rawValue)")
        Task { @MainActor in
            let peers = session.connectedPeers
            self.peerConnected = !peers.isEmpty
            self.connectedPeerName = peers.first?.displayName
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
