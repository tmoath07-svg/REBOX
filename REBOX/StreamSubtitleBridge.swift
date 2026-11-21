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
    // Zero means captions-only, avoiding black HDMI video on unsupported TVs.
    @Published var hdmiInput = 0 { didSet { hdmiRevision += 1; publish() } }
    private var hdmiRevision = 0
    @Published var showTVControls = true { didSet { publish() } }
    @Published var subtitleVisible = true { didSet { publish() } }
    @Published var message = "جاهز للإرسال"
    @Published var serverStatus = "جارٍ تشغيل السيرفر"
    @Published private(set) var tvRecentlyConnected = false
    private var lastTVPoll: Date?
    private var connectionMonitor: Timer?
    @Published private(set) var listeningPort: UInt16?

    let server = TVHTTPServer()

    // The port may change if another process is already using 8080.
    // Only advertise a URL after the listener has actually reached .ready.
    var tvURL: String {
        guard let listeningPort else { return "الرابط بيظهر بعد اتصال الخادم" }
        return "http://\(LANAddress.ipv4()):\(listeningPort)/tv"
    }

    var canShareURL: Bool {
        listeningPort != nil && LANAddress.ipv4() != "IP-الجهاز"
    }

    init() {
        server.onStatus = { [weak self] message in
            Task { @MainActor in self?.serverStatus = message }
        }
        server.onListeningPort = { [weak self] port in
            Task { @MainActor in self?.listeningPort = port }
        }
        server.onReceiverPoll = { [weak self] in
            Task { @MainActor in
                self?.lastTVPoll = Date()
                self?.tvRecentlyConnected = true
            }
        }
        connectionMonitor = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.tvRecentlyConnected = self.lastTVPoll.map {
                    Date().timeIntervalSince($0) < 7
                } ?? false
            }
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
            "background": boxColor,
            "hdmiInput": hdmiInput,
            "hdmiRevision": hdmiRevision,
            "showControls": showTVControls,
            "showSubtitle": subtitleVisible
        ]
        if let data = try? JSONSerialization.data(withJSONObject: snapshot) {
            server.update(payload: data)
        }
    }
}

nonisolated enum LANAddress {
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

nonisolated final class TVHTTPServer: @unchecked Sendable {
    var onStatus: ((String) -> Void)?
    var onListeningPort: ((UInt16?) -> Void)?
    var onReceiverPoll: (() -> Void)?
    private let queue = DispatchQueue(label: "rebox.tv.network", qos: .utility)
    private var listener: NWListener?
    private var attemptedAutomaticPort = false
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
        guard listener == nil else { return }
        listen(on: NWEndpoint.Port(rawValue: 8080)!)
    }

    // First try the familiar :8080 URL. If it is occupied (POSIX 48),
    // ask Network.framework to choose a free port instead of crashing.
    private func listen(on port: NWEndpoint.Port) {
        do {
            let candidate = try NWListener(using: .tcp, on: port)
            listener = candidate
            candidate.stateUpdateHandler = { [weak self, weak candidate] state in
                guard let self, let candidate, self.listener === candidate else { return }

                switch state {
                case .ready:
                    guard let openedPort = candidate.port?.rawValue else {
                        self.report("تعذر معرفة منفذ الخادم")
                        return
                    }
                    self.report("الخادم يعمل على المنفذ \(openedPort)", port: openedPort)

                case .waiting(let error):
                    if case .posix(let code) = error, code == .EADDRINUSE {
                        self.handleFailure(error)
                    } else {
                        self.report("بانتظار الشبكة: \(error.localizedDescription)")
                    }

                case .failed(let error):
                    self.handleFailure(error)

                default:
                    break
                }
            }
            candidate.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            candidate.start(queue: queue)
        } catch {
            handleFailure(error)
        }
    }

    private func handleFailure(_ error: Error) {
        listener?.cancel()
        listener = nil
        if !attemptedAutomaticPort {
            attemptedAutomaticPort = true
            report("المنفذ 8080 مشغول، جارٍ اختيار منفذ مجاني متاح...")
            listen(on: .any)
        } else {
            report("تعذر تشغيل الخادم: \(error.localizedDescription)")
        }
    }

    private func report(_ status: String, port: UInt16? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.onListeningPort?(port)
            self?.onStatus?(status)
        }
    }

    deinit {
        listener?.cancel()
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self else { connection.cancel(); return }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let first = request.components(separatedBy: "\r\n").first ?? ""
            let parts = first.split(separator: " ")
            let rawPath = parts.count >= 2 ? String(parts[1]) : "/"
            // Browser cache-busting queries such as /state?fresh=123 must not produce 404.
            let path = String(rawPath.split(separator: "?", maxSplits: 1,
                                            omittingEmptySubsequences: false).first ?? Substring("/"))
            switch path {
            case "/state":
                self.onReceiverPoll?()
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
<title>REBOX TV · HDMI Translator</title>
<style>
html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#070b12;color:white;font-family:Arial,Tahoma,sans-serif}
#video{position:absolute;top:0;left:0;width:100%;height:100%;background:transparent;object-fit:fill;display:none}
#overlay{position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;background:transparent}
#caption{position:absolute;top:75%;left:5%;width:90%;box-sizing:border-box;display:none;
  padding:10px 24px;border-radius:13px;white-space:pre-wrap;line-height:1.45;text-align:center;
  font-weight:bold;font-size:25pt;text-shadow:0 2px 6px #000}
#settings{position:absolute;top:5%;right:5%;width:540px;max-width:84%;padding:24px;box-sizing:border-box;
  background:rgba(9,17,31,.96);border:2px solid #65d9ff;border-radius:20px;box-shadow:0 10px 30px #000a}
h1{font-size:29px;margin:0 0 10px;color:#65d9ff}
p{font-size:18px;line-height:1.5;color:#d7e1ed}
button{font-size:19px;background:#162c3d;color:white;padding:12px 19px;border:1px solid #679ab8;
  border-radius:12px;margin:5px;cursor:pointer}
button.active,button:focus{background:#5ad7ff;color:#07151e;outline:2px solid white}
#status{font-size:15px;color:#80d9fa}
#tip{font-size:15px;color:#a6becb}
</style></head>
<body>
<video id="video" autoplay playsinline muted></video>
<div id="overlay"><div id="caption"></div></div>
<div id="settings">
  <h1>REBOX TV · ترجمة الألعاب</h1>
  <p>اختر مدخل Xbox. إذا كان متصفح LG يدعم HDMI داخل صفحة ويب، بتظهر اللعبة والترجمة معًا.</p>
  <div id="inputs">
    <button data-hdmi="1">HDMI 1</button><button data-hdmi="2">HDMI 2</button>
    <button data-hdmi="3">HDMI 3</button><button data-hdmi="4">HDMI 4</button>
  </div>
  <button id="off">شاشة الترجمة فقط</button>
  <button id="hide">إخفاء القائمة</button>
  <button id="fullscreen">ملء الشاشة (تجريبي)</button>
  <p id="status">جاري الاتصال بتطبيق الجوال...</p>
  <p id="tip">إذا لم تظهر صورة اللعبة، فهذه ميزة غير مدعومة على متصفح تلفزيونك. لا يلزم تغيير إعدادات النظام. اضغط OK لإظهار القائمة و Back لإخفائها.</p>
</div>
<script>
(function(){
  "use strict";
  var cap=document.getElementById("caption");
  var msg=document.getElementById("status");
  var panel=document.getElementById("settings");
  var video=document.getElementById("video");
  var current=0;
  var lastHDMIRevision=-1;
  var lastRemoteControls=null;
  function choose(port) {
    current=port;
    var buttons=document.querySelectorAll("[data-hdmi]");
    for(var i=0;i<buttons.length;i++) {
      buttons[i].className=Number(buttons[i].getAttribute("data-hdmi"))===port?"active":"";
    }
    if(port===0) {
      video.pause();video.removeAttribute("src");video.innerHTML="";video.load();
      video.style.display="none";
      msg.textContent="وضع الترجمة فقط. تقدر تختار HDMI للتجربة.";
      return;
    }
    // webOS Homebrew documents "service/webos-external" embedded HDMI.
    // This only partially works in some ordinary LG system browsers.
    video.style.display="block";
    video.innerHTML="";
    var source=document.createElement("source");
    source.setAttribute("type","service/webos-external");
    source.setAttribute("src","ext://hdmi:"+port);
    video.appendChild(source);
    video.load();
    var p=video.play();
    if(p&&p.catch) p.catch(function(){msg.textContent="متصفح LG قد لا يدعم HDMI المضمن";});
    msg.textContent="محاولة عرض HDMI "+port+" — إذا الصورة سوداء جرب مدخل ثاني";
  }
  function refresh(){
    var xhr=new XMLHttpRequest();
    xhr.open("GET","/state?fresh="+Date.now(),true);
    xhr.timeout=2500;
    xhr.onload=function() {
      if(xhr.status!==200){msg.textContent="تعذر قراءة الترجمة";return;}
      try {
        var s=JSON.parse(xhr.responseText);
        cap.textContent=String(s.subtitle||"");
        cap.style.display=(cap.textContent&&s.showSubtitle!==false)?"block":"none";
        var revision=Number(s.hdmiRevision||0);
        if(revision!==lastHDMIRevision){
          var wanted=Number(s.hdmiInput||0);
          if(wanted!==current && wanted>=0 && wanted<=4)choose(wanted);
          lastHDMIRevision=revision;
        }
        if(typeof s.showControls==="boolean" && s.showControls!==lastRemoteControls) {
          panel.style.display=s.showControls?"block":"none";
          lastRemoteControls=s.showControls;
        }
        cap.style.top=Math.max(0,Math.min(90,Number(s.position)||75))+"%";
        cap.style.fontSize=Math.max(16,Math.min(70,Number(s.fontSize)||25))+"pt";
        cap.style.color=/^#[0-9a-f]{6}$/i.test(s.color||"")?s.color:"#fff";
        var hex=/^#[0-9a-f]{6}$/i.test(s.background||"")?s.background:"#000000";
        var color=parseInt(hex.slice(1),16);
        var alpha=Math.max(0,Math.min(1,Number(s.opacity==null?.75:s.opacity)));
        cap.style.backgroundColor="rgba("+((color>>16)&255)+","+((color>>8)&255)+","+(color&255)+","+alpha+")";
        if(current===0)msg.textContent="REBOX TV متصل — جاهز للترجمة";
      } catch(error) {msg.textContent="بيانات الترجمة غير صالحة";}
    };
    xhr.onerror=function(){msg.textContent="انقطع الاتصال بالجوال"};
    xhr.ontimeout=xhr.onerror;
    xhr.send();
  }
  document.getElementById("inputs").addEventListener("click",function(e){
    if(e.target&&e.target.hasAttribute("data-hdmi"))choose(Number(e.target.getAttribute("data-hdmi")));
  });
  document.getElementById("off").addEventListener("click",function(){choose(0);});
  document.getElementById("hide").addEventListener("click",function(){panel.style.display="none";});
  document.getElementById("fullscreen").addEventListener("click",function(){
    var root=document.documentElement;
    var request=root.requestFullscreen||root.webkitRequestFullscreen;
    if(request){
      try{
        var result=request.call(root);
        if(result&&result.catch)result.catch(function(){msg.textContent="LG لم يسمح بوضع ملء الشاشة";});
      } catch(error){msg.textContent="LG لم يسمح بوضع ملء الشاشة";}
    }else{
      msg.textContent="متصفح LG لا يدعم ملء الشاشة عبر الصفحة";
    }
  });
  document.addEventListener("keydown",function(e){
    if(e.keyCode===461||e.key==="Escape"||e.key==="Backspace"){panel.style.display="none";e.preventDefault();}
    else if((e.key==="Enter"||e.keyCode===13)&&panel.style.display==="none"){panel.style.display="block";e.preventDefault();}
  });
  var param=new URLSearchParams(location.search).get("hdmi");
  if(["1","2","3","4"].indexOf(param)>=0)choose(Number(param));
  refresh();setInterval(refresh,700);
})();
</script></body></html>
"""#
}
