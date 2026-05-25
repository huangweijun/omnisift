(function () {
  var config = {
    appStoreUrl: "",
    pendingLabel: "Coming soon on the App Store / 即将在 App Store 上线",
    liveLabel: "Download on the App Store / 在 App Store 下载"
  };

  function applyAppStoreLinks() {
    var links = document.querySelectorAll("[data-app-store-link]");
    links.forEach(function (link) {
      if (config.appStoreUrl) {
        link.setAttribute("href", config.appStoreUrl);
        link.classList.remove("is-pending");
        link.removeAttribute("aria-disabled");
        link.textContent = link.getAttribute("data-live-label") || config.liveLabel;
      } else {
        link.setAttribute("href", "mailto:omnisift.app@gmail.com?subject=OmniSift%20launch%20notice");
        link.classList.add("is-pending");
        link.setAttribute("aria-disabled", "true");
        link.textContent = link.getAttribute("data-pending-label") || config.pendingLabel;
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", applyAppStoreLinks);
  } else {
    applyAppStoreLinks();
  }
})();
