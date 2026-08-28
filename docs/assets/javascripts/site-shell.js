(() => {
  const root = document.documentElement;
  let pageController;

  function applyTheme(theme) {
    const normalized = theme === "light" ? "light" : "dark";
    root.dataset.theme = normalized;
    root.style.colorScheme = normalized;
    document.body?.setAttribute("data-md-color-scheme", normalized === "light" ? "default" : "slate");

    const button = document.querySelector("[data-theme-toggle]");
    if (button) {
      const next = normalized === "dark" ? "light" : "dark";
      button.textContent = next;
      button.setAttribute("aria-label", `Switch to ${next} color scheme`);
    }
  }

  function setupPage() {
    pageController?.abort();
    pageController = new AbortController();
    const { signal } = pageController;
    const themeButton = document.querySelector("[data-theme-toggle]");
    const searchButton = document.querySelector("[data-search-toggle]");
    const drawerButton = document.querySelector("[data-drawer-toggle]");
    const searchClose = document.querySelector('.md-search .md-search__icon[for="__search"]');
    const searchToggle = document.querySelector("#__search");
    const drawerToggle = document.querySelector("#__drawer");
    const progress = document.querySelector("[data-reading-progress]");

    applyTheme(localStorage.getItem("om-theme") || "dark");

    const activateOnKeyboard = (control) => {
      control?.addEventListener(
        "keydown",
        (event) => {
          if (event.key !== "Enter" && event.key !== " ") return;
          event.preventDefault();
          control.click();
        },
        { signal },
      );
    };

    const syncControls = () => {
      const searchIsOpen = Boolean(searchToggle?.checked);
      const drawerIsOpen = Boolean(drawerToggle?.checked);
      searchButton?.setAttribute("aria-expanded", String(searchIsOpen));
      drawerButton?.setAttribute("aria-expanded", String(drawerIsOpen));
      drawerButton?.setAttribute("aria-label", drawerIsOpen ? "Close navigation" : "Open navigation");
    };

    searchClose?.setAttribute("aria-label", "Close search");
    searchClose?.setAttribute("role", "button");
    searchClose?.setAttribute("tabindex", "0");
    activateOnKeyboard(searchButton);
    activateOnKeyboard(drawerButton);
    activateOnKeyboard(searchClose);

    searchToggle?.addEventListener(
      "change",
      () => {
        if (searchToggle.checked && drawerToggle?.checked) drawerToggle.checked = false;
        syncControls();
      },
      { signal },
    );

    drawerToggle?.addEventListener(
      "change",
      () => {
        if (drawerToggle.checked && searchToggle?.checked) searchToggle.checked = false;
        syncControls();
      },
      { signal },
    );

    document.addEventListener(
      "keydown",
      (event) => {
        if (event.key !== "Escape") return;
        if (searchToggle?.checked) {
          searchToggle.checked = false;
          syncControls();
          searchButton?.focus();
        } else if (drawerToggle?.checked) {
          drawerToggle.checked = false;
          syncControls();
          drawerButton?.focus();
        }
      },
      { signal },
    );

    syncControls();

    themeButton?.addEventListener(
      "click",
      () => {
        const theme = root.dataset.theme === "dark" ? "light" : "dark";
        localStorage.setItem("om-theme", theme);
        applyTheme(theme);
      },
      { signal },
    );

    if (!progress) return;

    let scheduled = false;
    const renderProgress = () => {
      const available = document.documentElement.scrollHeight - window.innerHeight;
      const ratio = available > 0 ? Math.min(window.scrollY / available, 1) : 0;
      progress.style.transform = `scaleX(${ratio})`;
      scheduled = false;
    };
    const scheduleProgress = () => {
      if (scheduled) return;
      scheduled = true;
      requestAnimationFrame(renderProgress);
    };

    window.addEventListener("scroll", scheduleProgress, { passive: true, signal });
    window.addEventListener("resize", scheduleProgress, { signal });
    renderProgress();
  }

  if (typeof document$ !== "undefined") {
    document$.subscribe(setupPage);
  } else if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setupPage, { once: true });
  } else {
    setupPage();
  }
})();
