(function () {
  "use strict";
  var input = document.getElementById("server");
  var setup = document.getElementById("setup");
  var startButton = document.getElementById("start");
  var caption = document.getElementById("caption");
  var status = document.getElementById("state");
  var diagnostic = document.getElementById("diagnostic");
  var baseURL = localStorage.getItem("rebox-phone-address") || "";
  var poll = null, failures = 0, lastText = "";
  input.value = baseURL;

  function address(raw) {
    var s = String(raw || "").trim().replace(/\/(?:tv|state)\/?$/, "").replace(/\/+$/, "");
    if (!/^https?:\/\/[a-zA-Z0-9.:-]+$/i.test(s)) { return null; }
    return s;
  }

  function showSetup(show) {
    setup.style.display = show ? "block" : "none";
    diagnostic.style.display = show ? "none" : "block";
    if (show) { input.focus(); }
  }

  function blend(hex, transparency) {
    var h = String(hex || "#000000");
    if (!/^#[0-9a-fA-F]{6}$/.test(h)) h = "#000000";
    var num = parseInt(h.slice(1), 16);
    var alpha = Math.max(0, Math.min(1, Number(transparency)));
    return "rgba(" + ((num >> 16) & 255) + "," + ((num >> 8) & 255) + "," +
      (num & 255) + "," + alpha + ")";
  }

  function render(data) {
    var text = String(data.subtitle || "");
    caption.textContent = text;
    caption.style.display = text ? "block" : "none";
    caption.style.top = Math.max(0, Math.min(90, Number(data.position) || 75)) + "%";
    caption.style.fontSize = Math.max(16, Math.min(52, Number(data.fontSize) || 25)) + "pt";
    caption.style.color = /^#[0-9a-fA-F]{6}$/.test(data.color || "") ? data.color : "#ffffff";
    caption.style.backgroundColor = blend(data.background, data.opacity == null ? 0.75 : data.opacity);
    lastText = text;
    status.textContent = "تم الاتصال بالآيفون / الآيباد";
    diagnostic.textContent = text ? "" : "REBOX TV: متصل — بانتظار الترجمة";
    diagnostic.style.display = text || setup.style.display !== "none" ? "none" : "block";
    failures = 0;
  }

  function update() {
    if (!baseURL) return;
    var xhr = new XMLHttpRequest();
    xhr.open("GET", baseURL + "/state?ts=" + Date.now(), true);
    xhr.timeout = 2300;
    xhr.onload = function () {
      if (xhr.status !== 200) { failed(); return; }
      try { render(JSON.parse(xhr.responseText)); } catch (err) { failed(); }
    };
    xhr.onerror = failed;
    xhr.ontimeout = failed;
    xhr.send();
  }

  function failed() {
    failures++;
    if (failures > 2) {
      status.textContent = "الجهاز غير متصل — افتح REBOX TV على الآيفون وتأكد من IP والواي فاي";
      diagnostic.textContent = "REBOX TV: انقطع الاتصال";
      diagnostic.style.display = setup.style.display === "none" ? "block" : "none";
      // Clear stale captions instead of leaving an incorrect sentence over the game.
      caption.textContent = "";
      caption.style.display = "none";
    }
  }

  function start() {
    var cleaned = address(input.value);
    if (!cleaned) { status.textContent = "عنوان غير صحيح. مثال: http://192.168.0.100:8080"; return; }
    baseURL = cleaned;
    input.value = cleaned;
    localStorage.setItem("rebox-phone-address", cleaned);
    failures = 0;
    showSetup(false);
    if (poll) { clearInterval(poll); }
    update();
    poll = setInterval(update, 850);
  }

  startButton.addEventListener("click", start);
  input.addEventListener("keydown", function(event) {
    if (event.key === "Enter") { event.preventDefault(); start(); }
  });
  document.addEventListener("keydown", function(event) {
    if (event.key === "Backspace" || event.key === "Escape" || event.keyCode === 461) {
      event.preventDefault(); showSetup(false);
    } else if (event.key === "Enter" && setup.style.display === "none") {
      event.preventDefault(); showSetup(true);
    }
  });
  if (baseURL) { start(); } else { showSetup(true); }
})();
