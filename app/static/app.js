// DriveEase - small UI effects (no libraries)
(function () {
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Animations are switched on only once the browser is really painting frames.
  // Every element's final state is its default, so nothing can stay hidden.
  if (!reduce) requestAnimationFrame(function () { document.documentElement.classList.add("anim"); });

  // staggered fade-up for top-level page blocks
  document.querySelectorAll("main > *, .stagger > *").forEach(function (el, i) {
    if (el.classList.contains("toasts")) return;
    el.classList.add("reveal");
    el.style.setProperty("--i", Math.min(i, 12));
  });

  // test rows reveal one after another
  document.querySelectorAll("tr.tr-reveal").forEach(function (tr, i) {
    tr.style.setProperty("--i", i);
  });

  // count-up numbers: <span data-count="14">14</span>
  if (!reduce) {
    document.querySelectorAll("[data-count]").forEach(function (el) {
      var target = parseFloat(el.getAttribute("data-count")) || 0;
      var start = null, dur = 1100;
      function step(ts) {
        if (!start) { start = ts; el.textContent = "0"; }
        var p = Math.min((ts - start) / dur, 1);
        var eased = 1 - Math.pow(1 - p, 3);
        el.textContent = Math.round(target * eased).toLocaleString("en-IN");
        if (p < 1) requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    });
  }

  // toasts: close button + auto-dismiss successes
  function dismiss(t) {
    t.classList.add("out");
    setTimeout(function () { t.remove(); }, 320);
  }
  document.querySelectorAll(".toast").forEach(function (t) {
    var btn = t.querySelector("button");
    if (btn) btn.addEventListener("click", function () { dismiss(t); });
    if (!t.classList.contains("error")) setTimeout(function () { dismiss(t); }, 6000);
  });

  // live clock in the top bar (database time + elapsed seconds)
  var clock = document.querySelector("[data-dbtime]");
  if (clock) {
    var base = new Date(clock.getAttribute("data-dbtime").replace(" ", "T"));
    var t0 = Date.now();
    var out = clock.querySelector("b");
    setInterval(function () {
      var d = new Date(base.getTime() + (Date.now() - t0));
      out.textContent = d.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
    }, 1000);
  }
})();
