import UIKit
import CocoaAsyncSocket
import NotificationBannerSwift

protocol SocketControllerViewDelegate: class {
    func updatedState(state: SocketControllerState)
}

enum SocketControllerState {
    case waitingForHost
    case readyToReceive
}

class SocketController: NSObject, StreamDelegate, GCDAsyncUdpSocketDelegate {
    var delegate: SocketControllerViewDelegate?
    var broadCastListnerSocket: GCDAsyncUdpSocket?
    var outputSocket: GCDAsyncUdpSocket?
    
    var hostAddress: String?
    
    override init() {
        super.init()
        
        outputSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        broadCastListnerSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
    }
    
    func setupAutoDiscoveryListner(){
        
        do {
            try broadCastListnerSocket?.bind(toPort: 49452)
            try broadCastListnerSocket?.beginReceiving()
            
        } catch {
            NotificationBanner(title: "Uhh Oh!", subtitle: "There was a problem enabling Auto Discovery", style: .danger).show()
            print(error)
        }
        

        self.delegate?.updatedState(state: .waitingForHost)
    }
    
    func sendMessage(message: String) {
        
        guard hostAddress != nil else {return}
        
        let data = message.data(using: .ascii)!
        outputSocket?.send(data, toHost: hostAddress!, port: 49452, withTimeout: 0.1, tag: 0)
    }
    
    func closeSockets() {
        outputSocket?.close()
        broadCastListnerSocket?.close()
    }
    
    func openSockets() {
        setupAutoDiscoveryListner();
    }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let message  = String(data: data, encoding: String.Encoding.ascii)
        if (message?.contains("iPhoneMoCapBroadCast") ?? false) {
            
            var host: NSString?
            var port1: UInt16 = 0
            GCDAsyncUdpSocket.getHost(&host, port: &port1, fromAddress: address)
            
            if let host = host {
                hostReceived(host: String(host))
            }
        }
    }
    
    func restartAutoDiscovery() {
        setupAutoDiscoveryListner()
    }
    
    func hostReceived(host: String) {
        // Stop listening to broadcasts
        broadCastListnerSocket?.close()
        
        hostAddress = host
        
        self.delegate?.updatedState(state: .readyToReceive)
    }
}

