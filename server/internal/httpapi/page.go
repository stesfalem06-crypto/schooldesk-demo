package httpapi

var lockPage = []byte(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SchoolDesk</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: "Segoe UI", sans-serif; background: #f4f1ea; color: #1c2430; }
  main { max-width: 720px; margin: 0 auto; padding: 28px 18px 80px; }
  h1 { font-size: 40px; margin: 0 0 8px; }
  .card { background: white; border-radius: 18px; padding: 22px; box-shadow: 0 8px 24px rgba(28,36,48,.06); }
  .id { font-size: 34px; letter-spacing: 2px; font-weight: 800; color: #0e7c66; word-break: break-all; }
  img { width: 240px; height: 240px; }
  input { width: 100%; font-size: 20px; padding: 14px; border-radius: 12px; border: 2px solid #d5d0c6; }
  button { margin-top: 12px; background: #0e7c66; color: white; border: 0; border-radius: 14px; font-size: 22px; padding: 14px 18px; width: 100%; }
  .msg { font-size: 20px; }
  .ok { color: #1f8a4c; }
  .bad { color: #c5363a; }
  footer { position: fixed; left: 0; right: 0; bottom: 0; background: #1c2430; color: #f4f1ea; text-align: center; padding: 10px 12px; font-size: 13px; }
</style>
</head>
<body>
<main>
  <h1>SchoolDesk</h1>
  <p class="msg" id="lead">This school is locked.</p>
  <div class="card">
    <p>School computer number</p>
    <div class="id" id="mid">…</div>
    <p><img id="qr" alt="School computer number" src="/api/v1/license/qr.png"></p>
    <p>Type the unlock code</p>
    <input id="code" autocomplete="off" autocapitalize="characters">
    <button id="go" type="button">Unlock</button>
    <p class="msg" id="out"></p>
  </div>
</main>
<footer>Developed by 9 Multimedia and IT Solutions · SHAMM TESFALEM · 07162947</footer>
<script>
async function load() {
  const res = await fetch("/api/v1/license");
  const data = await res.json();
  document.getElementById("mid").textContent = data.machine_id || "";
  const out = document.getElementById("out");
  if (data.licensed) {
    document.getElementById("lead").textContent = data.school_name + " is unlocked.";
    out.className = "msg ok";
    out.textContent = "This school can be used.";
  }
}
document.getElementById("go").onclick = async function () {
  const out = document.getElementById("out");
  out.className = "msg";
  out.textContent = "Checking…";
  const res = await fetch("/api/v1/license/activate", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({code: document.getElementById("code").value})
  });
  const data = await res.json();
  if (data.licensed) {
    out.className = "msg ok";
    out.textContent = data.school_name + " is unlocked.";
    document.getElementById("lead").textContent = data.school_name + " is unlocked.";
  } else {
    out.className = "msg bad";
    out.textContent = data.error || "That code did not work.";
  }
};
load();
</script>
</body>
</html>`)
