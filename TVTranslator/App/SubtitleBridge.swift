import Foundation
import Network
import Darwin
import Combine

@MainActor
final class SubtitleBridge: ObservableObject {
    @Published var subtitle = "" { didSet { publish() } }
    @Published var position = 75.0 { didSet { publish() } }
    @Published var fontSize = 25.0 { didSet { publish() } }
    @Published var boxOpacity = 0.75 { didSet { publish() } }
    @Published var textColor = "#55D6FF" { didSet { publish() } }
    @Published var boxColor = "#101C2A" { didSet { publish() } }
    @Published var message = "جاهز للإرسال"
    @Published var serverStatus = "جارٍ تشغيل السيرفر"

    let server = TVHTTPServer()
    var tvURL: String { "http://\(LANAddress.ipv4()):8080/tv" }

    init() {
        server.onStatus = { [weak self] message in
            Task { @MainActor in self?.serverStatus = message }
        }
        server.start()
        publish()
    }

    private func publish() {
        let snapshot: [String: Any] = [
            "subtitle": subtitle,
            "position": Int(position),
            "fontSize": Int(fontSize),
            "opacity": boxOpacity,
            "color": textColor,
            "background": boxColor
        ]
        if let data = try? JSONSerialization.data(withJSONObject: snapshot) {
            server.update(payload: data)
        }
    }
}

enum LANAddress {
    static func ipv4() -> String {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return "IP-الجهاز" }
        defer { freeifaddrs(first) }
        var cursor = first
        while let item = cursor {
            if let sockaddr = item.pointee.ifa_addr,
               sockaddr.pointee.sa_family == UInt8(AF_INET),
               String(cString: item.pointee.ifa_name) == "en0" {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sockaddr, socklen_t(sockaddr.pointee.sa_len),
                               &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    return String(cString: buffer)
                }
            }
            cursor = item.pointee.ifa_next
        }
        return "IP-الجهاز"
    }
}

final class TVHTTPServer {
    var onStatus: ((String) -> Void)?
    private let queue = DispatchQueue(label: "rebox.tv.network", qos: .utility)
    private var listener: NWListener?
    private let lock = NSLock()
    private var stateData = Data("{}".utf8)

    func update(payload: Data) {
        lock.lock()
        stateData = payload
        lock.unlock()
    }

    private func getState() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return stateData
    }

    func start() {
        do {
            let newListener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: 8080)!)
            listener = newListener
            newListener.stateUpdateHandler = { [weak self] state in
                let text: String
                switch state {
                case .ready: text = "متصل: خادم الترجمة على المنفذ 8080"
                case .failed(let error): text = "تعطل الخادم: \(error.localizedDescription)"
                case .waiting(let error): text = "بانتظار الشبكة: \(error.localizedDescription)"
                default: return
                }
                DispatchQueue.main.async { self?.onStatus?(text) }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            newListener.start(queue: queue)
        } catch {
            onStatus?("تعذر فتح المنفذ: \(error.localizedDescription)")
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self else { connection.cancel(); return }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let first = request.components(separatedBy: "\r\n").first ?? ""
            let parts = first.split(separator: " ")
            let path = parts.count >= 2 ? String(parts[1]) : "/"
            switch path {
            case "/state":
                self.respond(connection, data: self.getState(), mime: "application/json; charset=utf-8")
            case "/", "/tv":
                self.respond(connection, data: Data(Self.tvHTML.utf8), mime: "text/html; charset=utf-8")
            default:
                self.respond(connection, data: Data("Not found".utf8), mime: "text/plain", status: "404 Not Found")
            }
        }
    }

    private func respond(_ connection: NWConnection, data: Data, mime: String, status: String = "200 OK") {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(mime)\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
        var packet = Data(header.utf8)
        packet.append(data)
        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }

    static let tvHTML = #"""
<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>REBOX TV</title>
<style>
html,body{margin:0;height:100%;background:transparent;overflow:hidden}
body{font-family:Arial,system-ui,sans-serif}
#caption{position:absolute;top:75%;left:5%;width:90%;border-radius:14px;
  box-sizing:border-box;white-space:pre-wrap;text-align:center;font-weight:bold;
  line-height:1.5;padding:10px 14px;text-shadow:0 2px 4px #000;display:none}
#status{position:absolute;left:20px;top:18px;padding:7px 10px;
  background:#111c;border-radius:10px;color:#84ddff;font:14px Arial}
</style></head>
<body>
<div id="status">REBOX TV — جاري الاتصال...</div>
<div id="caption"></div>
<script>
const cap=document.getElementById("caption");
const msg=document.getElementById("status");
async function refresh(){
 try{
  const response=await fetch("/state",{cache:"no-store"});
  if(!response.ok)throw Error("offline");
  const s=await response.json();
  cap.textContent=String(s.subtitle||"");
  cap.style.display=cap.textContent?"block":"none";
  cap.style.top=String(Number(s.position||75))+"%";
  cap.style.fontSize=String(Number(s.fontSize||25))+"pt";
  cap.style.color=String(s.color||"#fff");
  cap.style.backgroundColor=String(s.background||"#000");
  cap.style.opacity=String(Math.max(0,Math.min(1,Number(s.opacity??.75))));
  msg.textContent="REBOX TV — متصل";
  msg.style.display=cap.textContent?"none":"block";
 }catch(e){msg.textContent="REBOX TV — فقد الاتصال";msg.style.display="block"}
}
refresh();setInterval(refresh,700);
</script></body></html>
"""#
}
