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
    const primarySidebar = document.querySelector(".md-sidebar--primary");
    const drawerTocToggle = primarySidebar?.querySelector("#__toc");
    const progress = document.querySelector("[data-reading-progress]");

    applyTheme(localStorage.getItem("om-theme") || "dark");

    const currentPath = window.location.pathname.replace(/index\.html$/, "").replace(/\/$/, "") || "/";
    document.querySelectorAll(".site-nav a, .docs-home").forEach((link) => {
      const target = new URL(link.href, window.location.href);
      const targetPath = target.pathname.replace(/index\.html$/, "").replace(/\/$/, "") || "/";
      const active = target.origin === window.location.origin && targetPath === currentPath;
      link.classList.toggle("is-active", active);
      if (active) link.setAttribute("aria-current", "page");
      else link.removeAttribute("aria-current");
    });

    document.querySelectorAll(".md-typeset .headerlink").forEach((link) => {
      const heading = link.closest("h1, h2, h3, h4, h5, h6");
      if (!heading) return;
      const copy = heading.cloneNode(true);
      copy.querySelector(".headerlink")?.remove();
      const title = copy.textContent.trim();
      heading.setAttribute("aria-label", title);
      link.setAttribute("aria-label", `Permanent link to “${title}”`);
    });

    const tocLinks = [...document.querySelectorAll(".md-sidebar--secondary .md-nav--secondary .md-nav__link")];
    if (tocLinks.length && !tocLinks.some((link) => link.classList.contains("md-nav__link--active"))) {
      tocLinks[0].classList.add("md-nav__link--active");
    }

    const sourceToc = document.querySelector(".md-sidebar--secondary .md-nav--secondary > .md-nav__list");
    const pageLead = document.querySelector(".md-content__inner .page-lead");
    if (sourceToc && pageLead && tocLinks.length >= 6) {
      const details = document.createElement("details");
      details.className = "mobile-page-toc";
      details.dataset.mobilePageToc = "";

      const summary = document.createElement("summary");
      summary.innerHTML = '<span>On this page</span><span class="mobile-page-toc__marker" aria-hidden="true"></span>';

      const nav = document.createElement("nav");
      nav.className = "mobile-page-toc__nav";
      nav.setAttribute("aria-label", "On this page");
      const list = sourceToc.cloneNode(true);
      list.removeAttribute("data-md-component");
      list.removeAttribute("data-md-scrollfix");
      nav.append(list);
      details.append(summary, nav);
      pageLead.after(details);

      nav.addEventListener("click", (event) => {
        if (event.target.closest("a")) details.open = false;
      }, { signal });
    }

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

    const setTabbable = (elements, enabled) => {
      elements.forEach((element) => {
        if (enabled) {
          if (!("drawerTabindex" in element.dataset)) return;
          const original = element.dataset.drawerTabindex;
          if (original) element.setAttribute("tabindex", original);
          else element.removeAttribute("tabindex");
          delete element.dataset.drawerTabindex;
        } else {
          if (!("drawerTabindex" in element.dataset)) {
            element.dataset.drawerTabindex = element.getAttribute("tabindex") || "";
          }
          element.setAttribute("tabindex", "-1");
        }
      });
    };

    const syncDrawerFocus = () => {
      if (!primarySidebar) return;
      const drawerIsOpen = Boolean(drawerToggle?.checked);
      primarySidebar.inert = !drawerIsOpen;
      if (!drawerIsOpen) return;

      const secondaryNav = primarySidebar.querySelector(".md-nav--secondary");
      const all = [...primarySidebar.querySelectorAll('a, button, label[for], [tabindex]')];
      const secondary = secondaryNav ? all.filter((element) => secondaryNav.contains(element)) : [];
      const primary = secondaryNav ? all.filter((element) => !secondaryNav.contains(element)) : all;
      const tocIsOpen = Boolean(drawerTocToggle?.checked);
      setTabbable(primary, !tocIsOpen);
      setTabbable(secondary, tocIsOpen);
    };

    searchClose?.setAttribute("aria-label", "Close search");
    searchClose?.setAttribute("role", "button");
    searchClose?.setAttribute("tabindex", "0");
    activateOnKeyboard(searchButton);
    activateOnKeyboard(searchClose);

    drawerButton?.addEventListener(
      "click",
      () => {
        if (!drawerToggle) return;
        drawerToggle.checked = !drawerToggle.checked;
        drawerToggle.dispatchEvent(new Event("change", { bubbles: true }));
      },
      { signal },
    );

    searchToggle?.addEventListener(
      "change",
      () => {
        if (searchToggle.checked && drawerToggle?.checked) drawerToggle.checked = false;
        syncControls();
        syncDrawerFocus();
      },
      { signal },
    );

    drawerToggle?.addEventListener(
      "change",
      () => {
        if (drawerToggle.checked && searchToggle?.checked) searchToggle.checked = false;
        syncControls();
        syncDrawerFocus();
      },
      { signal },
    );

    drawerTocToggle?.addEventListener("change", syncDrawerFocus, { signal });

    document.addEventListener(
      "keydown",
      (event) => {
        if (event.key === "Tab" && drawerToggle?.checked && primarySidebar) {
          const focusable = [drawerButton, ...primarySidebar.querySelectorAll('a:not([tabindex="-1"]), button:not([tabindex="-1"]), label[for]:not([tabindex="-1"]), [tabindex]:not([tabindex="-1"])')]
            .filter((element) => !element.inert && element.getBoundingClientRect().width > 0);
          const first = focusable[0];
          const last = focusable[focusable.length - 1];
          if (event.shiftKey && document.activeElement === first) {
            event.preventDefault();
            last?.focus();
          } else if (!event.shiftKey && document.activeElement === last) {
            event.preventDefault();
            first?.focus();
          }
          return;
        }

        if (event.key !== "Escape") return;
        if (searchToggle?.checked) {
          searchToggle.checked = false;
          syncControls();
          searchButton?.focus();
        } else if (drawerToggle?.checked) {
          drawerToggle.checked = false;
          syncControls();
          syncDrawerFocus();
          drawerButton?.focus();
        }
      },
      { signal },
    );

    syncControls();
    syncDrawerFocus();

    const syncShortcutRows = () => {
      const rows = document.querySelectorAll(".shortcut-reference table:not(:has(th:nth-child(3))) tbody tr");
      rows.forEach((row) => row.classList.remove("shortcut-row--stacked"));
      if (window.innerWidth > 480) return;
      rows.forEach((row) => {
        const shortcut = row.querySelector("td:first-child");
        if (shortcut && shortcut.scrollWidth > shortcut.clientWidth + 1) {
          row.classList.add("shortcut-row--stacked");
        }
      });
    };

    let shortcutResizeScheduled = false;
    const scheduleShortcutRows = () => {
      if (shortcutResizeScheduled) return;
      shortcutResizeScheduled = true;
      requestAnimationFrame(() => {
        syncShortcutRows();
        shortcutResizeScheduled = false;
      });
    };
    window.addEventListener("resize", scheduleShortcutRows, { signal });
    syncShortcutRows();

    const shortcutFilter = document.querySelector("[data-shortcut-filter]");
    const shortcutQuery = shortcutFilter?.querySelector("[data-shortcut-query]");
    const shortcutClear = shortcutFilter?.querySelector("[data-shortcut-clear]");
    const shortcutStatus = shortcutFilter?.querySelector("[data-shortcut-status]");
    const shortcutEmpty = document.querySelector("[data-shortcut-empty]");
    const shortcutSections = [...document.querySelectorAll("[data-shortcut-section]")];
    const shortcutRows = shortcutSections.flatMap((section) => [...section.querySelectorAll("tbody tr")]);
    const shortcutHeadingIds = new Set(
      shortcutSections.flatMap((section) => [...section.querySelectorAll("h2[id], h3[id]")].map((heading) => heading.id)),
    );
    const shortcutTocRoots = [
      ...document.querySelectorAll(".md-nav--secondary"),
      ...document.querySelectorAll(".mobile-page-toc__nav"),
    ];
    let shortcutScope = "all";

    const syncShortcutToc = () => {
      shortcutTocRoots.forEach((toc) => {
        const links = [...toc.querySelectorAll('.md-nav__link[href*="#"]')];

        links.forEach((link) => {
          const id = decodeURIComponent(new URL(link.href, window.location.href).hash.slice(1));
          const heading = document.getElementById(id);
          const isFilterControlled = shortcutHeadingIds.has(id);
          const isHidden = isFilterControlled
            && (!heading || heading.hidden || Boolean(heading.closest("[data-shortcut-section][hidden]")));
          const item = link.closest(".md-nav__item");

          if (item) item.hidden = isHidden;
          if (isHidden) link.classList.remove("md-nav__link--active");
        });

        const visibleLinks = links.filter((link) => !link.closest(".md-nav__item")?.hidden);
        if (visibleLinks.length && !visibleLinks.some((link) => link.classList.contains("md-nav__link--active"))) {
          visibleLinks[0].classList.add("md-nav__link--active");
        }
      });
    };

    const syncShortcutFilter = () => {
      if (!shortcutFilter || !shortcutQuery) return;
      const query = shortcutQuery.value.toLocaleLowerCase().replace(/\s+/g, " ").trim();
      const queryTerms = query.split(/[\s+]+/).filter(Boolean);
      let visibleCount = 0;

      shortcutSections.forEach((section) => {
        const scopeMatches = shortcutScope === "all" || section.dataset.shortcutSection === shortcutScope;
        const rows = [...section.querySelectorAll("tbody tr")];
        rows.forEach((row) => {
          const searchText = row.textContent.toLocaleLowerCase().replace(/\s+/g, " ");
          const queryMatches = queryTerms.every((term) => searchText.includes(term));
          row.hidden = !scopeMatches || !queryMatches;
          if (!row.hidden) visibleCount += 1;
        });

        section.querySelectorAll(".md-typeset__scrollwrap").forEach((tableWrap) => {
          tableWrap.hidden = !tableWrap.querySelector("tbody tr:not([hidden])");
        });

        section.querySelectorAll("h3").forEach((heading) => {
          const group = [];
          let sibling = heading.nextElementSibling;
          while (sibling && !sibling.matches("h2, h3")) {
            group.push(sibling);
            sibling = sibling.nextElementSibling;
          }
          const groupHasMatch = group.some((element) => element.querySelector?.("tbody tr:not([hidden])"));
          heading.hidden = !groupHasMatch;
          group.forEach((element) => {
            if (element.matches(".md-typeset__scrollwrap")) element.hidden = !groupHasMatch;
          });
        });

        section.hidden = !scopeMatches || !rows.some((row) => !row.hidden);
      });

      shortcutClear.hidden = !query;
      shortcutEmpty.hidden = visibleCount !== 0;
      shortcutStatus.textContent = `Showing ${visibleCount} of ${shortcutRows.length} shortcuts`;
      syncShortcutToc();
      syncShortcutRows();
      syncDrawerFocus();
    };

    if (shortcutFilter && shortcutQuery && shortcutClear && shortcutStatus && shortcutEmpty) {
      shortcutFilter.classList.add("is-ready");
      shortcutFilter.addEventListener("submit", (event) => event.preventDefault(), { signal });
      shortcutQuery.addEventListener("input", syncShortcutFilter, { signal });
      shortcutQuery.addEventListener("keydown", (event) => {
        if (event.key !== "Escape" || !shortcutQuery.value) return;
        shortcutQuery.value = "";
        syncShortcutFilter();
      }, { signal });
      shortcutClear.addEventListener("click", () => {
        shortcutQuery.value = "";
        shortcutQuery.focus();
        syncShortcutFilter();
      }, { signal });
      shortcutFilter.querySelectorAll("[data-shortcut-scope]").forEach((button) => {
        button.addEventListener("click", () => {
          shortcutScope = button.dataset.shortcutScope;
          shortcutFilter.querySelectorAll("[data-shortcut-scope]").forEach((candidate) => {
            candidate.setAttribute("aria-pressed", String(candidate === button));
          });
          syncShortcutFilter();
        }, { signal });
      });
      syncShortcutFilter();
    }

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
