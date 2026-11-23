package httpapi

import (
	"fmt"
	"html"
	"net"
	"net/http"
	"strings"

	"github.com/skip2/go-qrcode"

	"schooldesk/internal/brand"
)

func (a *API) home(w http.ResponseWriter, r *http.Request) {
	host := advertiseHost(r)
	st, _ := a.Gate.Current(a.now())
	lead := "This school is locked."
	if st.Licensed {
		name := st.SchoolName
		if name == "" {
			name = "This school"
		}
		lead = name + " is unlocked."
	}
	page := fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; font-family: "Segoe UI", sans-serif; background: #f3f7fb; color: #16324f; }
  header { background: linear-gradient(120deg, #14b8c4, #0b63c4); color: white; padding: 28px 18px 22px; }
  header h1 { margin: 0; font-size: 34px; }
  header p { margin: 8px 0 0; font-size: 18px; }
  main { max-width: 820px; margin: 0 auto; padding: 22px 16px 90px; }
  .card { background: white; border-radius: 18px; padding: 20px; margin: 0 0 16px; box-shadow: 0 8px 24px rgba(11,50,90,.08); }
  .big { font-size: 32px; font-weight: 800; color: #0b63c4; word-break: break-all; }
  img { width: 260px; height: 260px; }
  input { width: 100%%; font-size: 20px; padding: 14px; border-radius: 12px; border: 2px solid #d5e2ee; }
  button { margin-top: 12px; background: #0b63c4; color: white; border: 0; border-radius: 14px; font-size: 22px; padding: 14px 18px; width: 100%%; }
  .ok { color: #1f8a4c; font-size: 20px; }
  .bad { color: #c5363a; font-size: 20px; }
  footer { position: fixed; left: 0; right: 0; bottom: 0; background: #16324f; color: #f4f1ea; text-align: center; padding: 10px 12px; font-size: 14px; }
</style>
</head>
<body>
<header>
  <h1>%s</h1>
  <p id="lead">%s</p>
</header>
<main>
  <div class="card">
    <p>The school address</p>
    <div class="big" id="addr">http://%s</div>
    <p>On a phone, open the app and point it at this picture.</p>
    <p><img alt="School address" src="/api/v1/join.png"></p>
  </div>
  <div class="card">
    <p>School computer number</p>
    <div class="big" id="mid">%s</div>
    <p>Type the unlock code</p>
    <input id="code" autocomplete="off">
    <button id="go" type="button">Unlock</button>
    <p id="out"></p>
  </div>
  <div class="card">
    <p>Update the program from a file. The school records stay.</p>
    <form id="up" enctype="multipart/form-data" method="post" action="/api/v1/update">
      <input name="file" type="file" accept=".smsu">
      <button type="submit">Update</button>
    </form>
    <p id="upout"></p>
    <button id="back" type="button">Put the previous program back</button>
  </div>
</main>
<footer>%s</footer>
<script>
document.getElementById("go").onclick = async function () {
  const out = document.getElementById("out");
  out.className = "";
  out.textContent = "Checking…";
  const res = await fetch("/api/v1/license/activate", {
    method: "POST", headers: {"Content-Type": "application/json"},
    body: JSON.stringify({code: document.getElementById("code").value})
  });
  const data = await res.json();
  if (data.licensed) {
    out.className = "ok";
    out.textContent = (data.school_name || "This school") + " is unlocked.";
    document.getElementById("lead").textContent = out.textContent;
  } else {
    out.className = "bad";
    out.textContent = data.error || "That code did not work.";
  }
};
document.getElementById("up").onsubmit = async function (ev) {
  ev.preventDefault();
  const out = document.getElementById("upout");
  out.textContent = "Checking the file…";
  const body = new FormData(ev.target);
  const res = await fetch("/api/v1/update", {method: "POST", body: body});
  const data = await res.json();
  out.className = res.ok ? "ok" : "bad";
  out.textContent = data.message || data.error || "That did not work.";
};
document.getElementById("back").onclick = async function () {
  const out = document.getElementById("upout");
  const res = await fetch("/api/v1/update/rollback", {method: "POST"});
  const data = await res.json();
  out.className = res.ok ? "ok" : "bad";
  out.textContent = data.message || data.error || "That did not work.";
};
</script>
</body>
</html>`,
		html.EscapeString(brand.Product),
		html.EscapeString(brand.Product),
		html.EscapeString(lead),
		html.EscapeString(host),
		html.EscapeString(st.MachineID),
		html.EscapeString(brand.Footer),
	)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(page))
}

func (a *API) joinQR(w http.ResponseWriter, r *http.Request) {
	payload := "http://" + advertiseHost(r)
	png, err := qrcode.Encode(payload, qrcode.Medium, 360)
	if err != nil {
		a.fail(w, 500, "The picture could not be made")
		return
	}
	w.Header().Set("Content-Type", "image/png")
	_, _ = w.Write(png)
}

func advertiseHost(r *http.Request) string {
	host := r.Host
	if host == "" {
		host = "127.0.0.1:8741"
	}
	name, port, err := net.SplitHostPort(host)
	if err != nil {
		name = host
		port = "8741"
	}
	if name == "127.0.0.1" || name == "localhost" || name == "::1" {
		if ip := firstLANIP(); ip != "" {
			return ip + ":" + port
		}
	}
	return host
}

func firstLANIP() string {
	ifaces, err := net.Interfaces()
	if err != nil {
		return ""
	}
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			ip = ip.To4()
			if ip == nil || ip.IsLoopback() {
				continue
			}
			return ip.String()
		}
	}
	return ""
}

func isLocal(r *http.Request) bool {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	return host == "127.0.0.1" || host == "::1" || strings.HasPrefix(host, "127.")
}
