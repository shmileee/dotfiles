(() => {
  let pageController;

  function normalizePersistentNavigationLinks() {
    const links = document.querySelectorAll(
      '[data-md-component="header"] a[href], .md-sidebar--primary a[href]'
    );

    links.forEach((link) => {
      const href = link.getAttribute('href');
      if (href === null || href.startsWith('#')) return;

      const target = new URL(href, window.location.href);
      if (target.origin !== window.location.origin) return;

      link.setAttribute(
        'href',
        `${target.pathname}${target.search}${target.hash}`
      );
    });
  }

  function setupPage() {
    pageController?.abort();
    pageController = new AbortController();
    const { signal } = pageController;
    document.querySelectorAll('body > [data-context-ui]').forEach((element) => {
      element.remove();
    });
    const contextHelpTrigger = document.querySelector(
      '.md-content [data-context-open]'
    );
    const contextHelpDialog = document.querySelector(
      '.md-content [data-context-dialog]'
    );
    if (contextHelpTrigger && contextHelpDialog) {
      document.body.append(contextHelpTrigger, contextHelpDialog);
    }
    const searchButton = document.querySelector('[data-search-toggle]');
    const drawerButton = document.querySelector('[data-drawer-toggle]');
    const drawerToggle = document.querySelector('#__drawer');
    const primarySidebar = document.querySelector('.md-sidebar--primary');
    const drawerTocToggle = primarySidebar?.querySelector('#__toc');
    const drawerTocLabels = [
      ...(primarySidebar?.querySelectorAll('label[for="__toc"]') || []),
    ];
    const progress = document.querySelector('[data-reading-progress]');

    normalizePersistentNavigationLinks();

    document.querySelector('.md-overlay')?.setAttribute('aria-hidden', 'true');
    document.querySelectorAll('.md-code__nav').forEach((nav, index) => {
      nav.setAttribute('aria-label', `Code block ${index + 1} actions`);
    });

    const enhanceInjectedSearch = () => {
      const searchHost = [...document.querySelectorAll('body > div')].find(
        (element) => element.shadowRoot?.querySelector('input[role="combobox"]')
      );
      const searchRoot = searchHost?.shadowRoot;
      const searchInput = searchRoot?.querySelector('input[role="combobox"]');
      if (!searchHost || !searchRoot || !searchInput) return false;

      const searchToolbar = searchInput.parentElement?.parentElement;
      const searchButtons = [
        ...(searchToolbar?.querySelectorAll('button') || []),
      ];
      const searchResults = searchRoot.querySelector('ol');
      const filterHeading = [...searchRoot.querySelectorAll('h3')].find(
        (heading) => heading.textContent.trim() === 'Filters'
      );
      const filterPanel = filterHeading?.parentElement?.parentElement;
      let searchPanel = searchToolbar;
      while (
        searchPanel &&
        !(
          searchPanel.contains(searchResults) &&
          searchPanel.contains(filterPanel)
        )
      ) {
        searchPanel = searchPanel.parentElement;
      }

      searchHost.setAttribute('role', 'search');
      searchHost.setAttribute('aria-label', 'Site search');
      searchInput.setAttribute('aria-label', 'Search documentation');
      searchInput.setAttribute('aria-autocomplete', 'list');
      if (searchResults) {
        searchResults.id = 'site-search-results';
        searchResults.setAttribute('role', 'listbox');
        searchInput.setAttribute('aria-controls', searchResults.id);
      }
      if (searchButtons[0])
        searchButtons[0].setAttribute('aria-label', 'Search documentation');
      if (searchButtons[1] && filterPanel) {
        filterPanel.id = 'site-search-filters';
        filterPanel.setAttribute('role', 'region');
        filterPanel.setAttribute('aria-label', 'Search filters');
        searchButtons[1].setAttribute('aria-label', 'Toggle search filters');
        searchButtons[1].setAttribute('aria-controls', filterPanel.id);
      }

      const syncInjectedSearch = () => {
        const searchIsOpen =
          searchPanel && getComputedStyle(searchPanel).pointerEvents !== 'none';
        searchInput.setAttribute(
          'aria-expanded',
          String(Boolean(searchIsOpen))
        );
        const filtersAreOpen =
          filterPanel &&
          getComputedStyle(filterPanel).pointerEvents !== 'none' &&
          filterPanel.getBoundingClientRect().width > 1;
        if (filterPanel) {
          filterPanel.setAttribute('aria-hidden', String(!filtersAreOpen));
          filterPanel.tabIndex = filtersAreOpen ? 0 : -1;
        }
        searchButtons[1]?.setAttribute(
          'aria-expanded',
          String(Boolean(filtersAreOpen))
        );
      };
      const injectedSearchObserver = new MutationObserver(syncInjectedSearch);
      if (searchPanel) {
        injectedSearchObserver.observe(searchPanel, {
          attributes: true,
          attributeFilter: ['class'],
        });
        searchPanel.addEventListener('transitionend', syncInjectedSearch, {
          signal,
        });
      }
      if (filterPanel) {
        injectedSearchObserver.observe(filterPanel, {
          attributes: true,
          attributeFilter: ['class'],
        });
        filterPanel.addEventListener('transitionend', syncInjectedSearch, {
          signal,
        });
      }
      signal.addEventListener(
        'abort',
        () => injectedSearchObserver.disconnect(),
        { once: true }
      );
      syncInjectedSearch();
      return true;
    };
    if (!enhanceInjectedSearch()) {
      let searchEnhancementAttempts = 0;
      const searchEnhancementTimer = window.setInterval(() => {
        searchEnhancementAttempts += 1;
        if (enhanceInjectedSearch() || searchEnhancementAttempts >= 100) {
          window.clearInterval(searchEnhancementTimer);
        }
      }, 50);
      signal.addEventListener(
        'abort',
        () => window.clearInterval(searchEnhancementTimer),
        { once: true }
      );
    }

    const closeContextHelp = () => {
      if (!contextHelpDialog?.open) return;
      if (typeof contextHelpDialog.close === 'function')
        contextHelpDialog.close();
      else contextHelpDialog.removeAttribute('open');
    };

    contextHelpTrigger?.addEventListener(
      'click',
      () => {
        if (!contextHelpDialog || contextHelpDialog.open) return;
        if (typeof contextHelpDialog.showModal === 'function')
          contextHelpDialog.showModal();
        else contextHelpDialog.setAttribute('open', '');
      },
      { signal }
    );
    contextHelpDialog
      ?.querySelector('[data-context-close]')
      ?.addEventListener('click', closeContextHelp, { signal });
    contextHelpDialog?.addEventListener(
      'click',
      (event) => {
        if (event.target !== contextHelpDialog) return;
        const bounds = contextHelpDialog.getBoundingClientRect();
        const isInside =
          event.clientX >= bounds.left &&
          event.clientX <= bounds.right &&
          event.clientY >= bounds.top &&
          event.clientY <= bounds.bottom;
        if (!isInside) closeContextHelp();
      },
      { signal }
    );
    contextHelpDialog?.addEventListener(
      'close',
      () => contextHelpTrigger?.focus(),
      { signal }
    );

    const currentPath =
      window.location.pathname.replace(/index\.html$/, '').replace(/\/$/, '') ||
      '/';
    document.querySelectorAll('.site-nav a, .docs-home').forEach((link) => {
      const target = new URL(link.href, window.location.href);
      const targetPath =
        target.pathname.replace(/index\.html$/, '').replace(/\/$/, '') || '/';
      const active =
        target.origin === window.location.origin && targetPath === currentPath;
      link.classList.toggle('is-active', active);
      if (active) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });

    document.querySelectorAll('.md-typeset .headerlink').forEach((link) => {
      const heading = link.closest('h1, h2, h3, h4, h5, h6');
      if (!heading) return;
      const copy = heading.cloneNode(true);
      copy.querySelector('.headerlink')?.remove();
      const title = copy.textContent.trim();
      heading.setAttribute('aria-label', title);
      link.setAttribute('aria-label', `Permanent link to “${title}”`);
    });

    const tocLinks = [
      ...document.querySelectorAll(
        '.md-sidebar--secondary .md-nav--secondary .md-nav__link'
      ),
    ];
    if (
      tocLinks.length &&
      !tocLinks.some((link) => link.classList.contains('md-nav__link--active'))
    ) {
      tocLinks[0].classList.add('md-nav__link--active');
    }

    const sourceToc = document.querySelector(
      '.md-sidebar--secondary .md-nav--secondary > .md-nav__list'
    );
    const pageLead = document.querySelector('.md-content__inner .page-lead');
    const mobileTocAnchor =
      document.querySelector('[data-mobile-toc-anchor]') || pageLead;
    if (sourceToc && mobileTocAnchor && tocLinks.length >= 6) {
      const details = document.createElement('details');
      details.className = 'mobile-page-toc';
      details.dataset.mobilePageToc = '';

      const summary = document.createElement('summary');
      summary.innerHTML = `<span class="mobile-page-toc__label"><strong>On this page</strong><small>${tocLinks.length} sections</small></span><span class="mobile-page-toc__marker" aria-hidden="true"></span>`;

      const nav = document.createElement('nav');
      nav.className = 'mobile-page-toc__nav';
      nav.setAttribute('aria-label', 'On this page');
      const list = sourceToc.cloneNode(true);
      list.removeAttribute('data-md-component');
      list.removeAttribute('data-md-scrollfix');
      nav.append(list);
      details.append(summary, nav);
      mobileTocAnchor.after(details);

      const mobileTocLinks = [
        ...nav.querySelectorAll('.md-nav__link[href*="#"]'),
      ];
      const syncMobileToc = () => {
        const activeHref = tocLinks
          .find((link) => link.classList.contains('md-nav__link--active'))
          ?.getAttribute('href');
        mobileTocLinks.forEach((link) => {
          link.classList.toggle(
            'md-nav__link--active',
            link.getAttribute('href') === activeHref
          );
        });
      };
      const tocObserver = new MutationObserver(syncMobileToc);
      tocObserver.observe(sourceToc, {
        subtree: true,
        attributes: true,
        attributeFilter: ['class'],
      });
      signal.addEventListener('abort', () => tocObserver.disconnect(), {
        once: true,
      });
      syncMobileToc();

      nav.addEventListener(
        'click',
        (event) => {
          const link = event.target.closest('a');
          if (!link) return;
          mobileTocLinks.forEach((item) => {
            item.classList.toggle('md-nav__link--active', item === link);
          });
          details.open = false;
        },
        { signal }
      );
    }

    const syncControls = () => {
      const drawerIsOpen = Boolean(drawerToggle?.checked);
      drawerButton?.setAttribute('aria-expanded', String(drawerIsOpen));
      drawerButton?.setAttribute(
        'aria-label',
        drawerIsOpen ? 'Close navigation' : 'Open navigation'
      );
      drawerTocLabels.forEach((label) => {
        label.setAttribute(
          'aria-expanded',
          String(Boolean(drawerTocToggle?.checked))
        );
      });
    };

    drawerTocLabels.forEach((label) => {
      label.setAttribute('role', 'button');
      label.tabIndex = 0;
      label.addEventListener(
        'keydown',
        (event) => {
          if (event.key !== ' ') return;
          event.preventDefault();
          label.click();
        },
        { signal }
      );
    });

    const setTabbable = (elements, enabled) => {
      elements.forEach((element) => {
        if (enabled) {
          if (!('drawerTabindex' in element.dataset)) return;
          const original = element.dataset.drawerTabindex;
          if (original) element.setAttribute('tabindex', original);
          else element.removeAttribute('tabindex');
          delete element.dataset.drawerTabindex;
        } else {
          if (!('drawerTabindex' in element.dataset)) {
            element.dataset.drawerTabindex =
              element.getAttribute('tabindex') || '';
          }
          element.setAttribute('tabindex', '-1');
        }
      });
    };

    const syncDrawerFocus = () => {
      if (!primarySidebar) return;
      const drawerIsOpen = Boolean(drawerToggle?.checked);
      primarySidebar.inert = !drawerIsOpen;
      if (!drawerIsOpen) return;

      const secondaryNav = primarySidebar.querySelector('.md-nav--secondary');
      const all = [
        ...primarySidebar.querySelectorAll('a, button, label[for], [tabindex]'),
      ];
      const secondary = secondaryNav
        ? all.filter((element) => secondaryNav.contains(element))
        : [];
      const primary = secondaryNav
        ? all.filter((element) => !secondaryNav.contains(element))
        : all;
      const tocIsOpen = Boolean(drawerTocToggle?.checked);
      setTabbable(primary, !tocIsOpen);
      setTabbable(secondary, tocIsOpen);
    };

    searchButton?.addEventListener(
      'click',
      () => {
        if (drawerToggle?.checked) {
          drawerToggle.checked = false;
          drawerToggle.dispatchEvent(new Event('change', { bubbles: true }));
        }
        document
          .querySelector("[data-md-component='search']")
          ?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      },
      { signal }
    );

    drawerButton?.addEventListener(
      'click',
      () => {
        if (!drawerToggle) return;
        drawerToggle.checked = !drawerToggle.checked;
        drawerToggle.dispatchEvent(new Event('change', { bubbles: true }));
      },
      { signal }
    );

    drawerToggle?.addEventListener(
      'change',
      () => {
        syncControls();
        syncDrawerFocus();
      },
      { signal }
    );

    drawerTocToggle?.addEventListener(
      'change',
      () => {
        syncControls();
        syncDrawerFocus();
      },
      { signal }
    );

    document.addEventListener(
      'keydown',
      (event) => {
        if (event.key === 'Tab' && drawerToggle?.checked && primarySidebar) {
          const focusable = [
            drawerButton,
            ...primarySidebar.querySelectorAll(
              'a:not([tabindex="-1"]), button:not([tabindex="-1"]), label[for]:not([tabindex="-1"]), [tabindex]:not([tabindex="-1"])'
            ),
          ].filter(
            (element) =>
              !element.inert && element.getBoundingClientRect().width > 0
          );
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

        if (event.key !== 'Escape') return;
        if (drawerToggle?.checked) {
          drawerToggle.checked = false;
          syncControls();
          syncDrawerFocus();
          drawerButton?.focus();
        }
      },
      { signal }
    );

    syncControls();
    syncDrawerFocus();

    const shortcutFilter = document.querySelector('[data-shortcut-filter]');
    const shortcutQuery = shortcutFilter?.querySelector(
      '[data-shortcut-query]'
    );
    const shortcutClear = shortcutFilter?.querySelector(
      '[data-shortcut-clear]'
    );
    const shortcutStatus = shortcutFilter?.querySelector(
      '[data-shortcut-status]'
    );
    const shortcutEmpty = document.querySelector('[data-shortcut-empty]');
    const shortcutSections = [
      ...document.querySelectorAll('[data-shortcut-section]'),
    ];
    const shortcutRows = shortcutSections.flatMap((section) => [
      ...section.querySelectorAll('tbody tr'),
    ]);
    const shortcutHeadingIds = new Set(
      shortcutSections.flatMap((section) =>
        [...section.querySelectorAll('h2[id], h3[id]')].map(
          (heading) => heading.id
        )
      )
    );
    const shortcutTocRoots = [
      ...document.querySelectorAll('.md-nav--secondary'),
      ...document.querySelectorAll('.mobile-page-toc__nav'),
    ];
    let shortcutScope = 'all';

    const syncShortcutToc = () => {
      shortcutTocRoots.forEach((toc) => {
        const links = [...toc.querySelectorAll('.md-nav__link[href*="#"]')];

        links.forEach((link) => {
          const id = decodeURIComponent(
            new URL(link.href, window.location.href).hash.slice(1)
          );
          const heading = document.getElementById(id);
          const isFilterControlled = shortcutHeadingIds.has(id);
          const isHidden =
            isFilterControlled &&
            (!heading ||
              heading.hidden ||
              Boolean(heading.closest('[data-shortcut-section][hidden]')));
          const item = link.closest('.md-nav__item');

          if (item) item.hidden = isHidden;
          if (isHidden) link.classList.remove('md-nav__link--active');
        });

        const visibleLinks = links.filter(
          (link) => !link.closest('.md-nav__item')?.hidden
        );
        if (
          visibleLinks.length &&
          !visibleLinks.some((link) =>
            link.classList.contains('md-nav__link--active')
          )
        ) {
          visibleLinks[0].classList.add('md-nav__link--active');
        }
      });
    };

    const syncShortcutFilter = () => {
      if (!shortcutFilter || !shortcutQuery) return;
      const query = shortcutQuery.value
        .toLocaleLowerCase()
        .replace(/\s+/g, ' ')
        .trim();
      const queryTerms = query.split(/[\s+]+/).filter(Boolean);
      let visibleCount = 0;

      shortcutSections.forEach((section) => {
        const scopeMatches =
          shortcutScope === 'all' ||
          section.dataset.shortcutSection === shortcutScope;
        const rows = [...section.querySelectorAll('tbody tr')];
        rows.forEach((row) => {
          const searchText = row.textContent
            .toLocaleLowerCase()
            .replace(/\s+/g, ' ');
          const queryMatches = queryTerms.every((term) =>
            searchText.includes(term)
          );
          row.hidden = !scopeMatches || !queryMatches;
          if (!row.hidden) visibleCount += 1;
        });

        rows.forEach((row) => {
          row.classList.remove('is-shortcut-mode-start');
          row.cells[0]?.removeAttribute('data-shortcut-mode-count');
        });

        if (section.dataset.shortcutSection === 'neovim') {
          const visibleModes = new Map();
          rows
            .filter((row) => !row.hidden)
            .forEach((row) => {
              const mode = row.querySelector('.shortcut-mode')?.textContent;
              if (!mode) return;
              const modeRows = visibleModes.get(mode) ?? [];
              modeRows.push(row);
              visibleModes.set(mode, modeRows);
            });

          visibleModes.forEach((modeRows) => {
            const modeCell = modeRows[0].cells[0];
            modeRows[0].classList.add('is-shortcut-mode-start');
            modeCell.dataset.shortcutModeCount = `${modeRows.length} shortcut${
              modeRows.length === 1 ? '' : 's'
            }`;
          });
        }

        section
          .querySelectorAll('.md-typeset__scrollwrap')
          .forEach((tableWrap) => {
            tableWrap.hidden = !tableWrap.querySelector(
              'tbody tr:not([hidden])'
            );
          });

        section.querySelectorAll('h3').forEach((heading) => {
          const group = [];
          let sibling = heading.nextElementSibling;
          while (sibling && !sibling.matches('h2, h3')) {
            group.push(sibling);
            sibling = sibling.nextElementSibling;
          }
          const groupHasMatch = group.some((element) =>
            element.querySelector?.('tbody tr:not([hidden])')
          );
          heading.hidden = !groupHasMatch;
          group.forEach((element) => {
            if (element.matches('.md-typeset__scrollwrap'))
              element.hidden = !groupHasMatch;
          });
        });

        section.hidden = !scopeMatches || !rows.some((row) => !row.hidden);
      });

      shortcutClear.hidden = !query;
      shortcutEmpty.hidden = visibleCount !== 0;
      shortcutStatus.textContent = `Showing ${visibleCount} of ${shortcutRows.length} shortcuts`;
      syncShortcutToc();
      syncDrawerFocus();
    };

    if (
      shortcutFilter &&
      shortcutQuery &&
      shortcutClear &&
      shortcutStatus &&
      shortcutEmpty
    ) {
      shortcutFilter.classList.add('is-ready');
      shortcutQuery.addEventListener('input', syncShortcutFilter, { signal });
      shortcutQuery.addEventListener(
        'keydown',
        (event) => {
          if (event.key !== 'Escape' || !shortcutQuery.value) return;
          shortcutQuery.value = '';
          syncShortcutFilter();
        },
        { signal }
      );
      shortcutClear.addEventListener(
        'click',
        () => {
          shortcutQuery.value = '';
          shortcutQuery.focus();
          syncShortcutFilter();
        },
        { signal }
      );
      shortcutFilter
        .querySelectorAll('[data-shortcut-scope]')
        .forEach((button) => {
          button.addEventListener(
            'click',
            () => {
              shortcutScope = button.dataset.shortcutScope;
              shortcutFilter
                .querySelectorAll('[data-shortcut-scope]')
                .forEach((candidate) => {
                  candidate.setAttribute(
                    'aria-pressed',
                    String(candidate === button)
                  );
                });
              syncShortcutFilter();
            },
            { signal }
          );
        });
      syncShortcutFilter();
    }

    if (!progress) return;

    let scheduled = false;
    const renderProgress = () => {
      const available =
        document.documentElement.scrollHeight - window.innerHeight;
      const ratio = available > 0 ? Math.min(window.scrollY / available, 1) : 0;
      progress.style.transform = `scaleX(${ratio})`;
      scheduled = false;
    };
    const scheduleProgress = () => {
      if (scheduled) return;
      scheduled = true;
      requestAnimationFrame(renderProgress);
    };

    window.addEventListener('scroll', scheduleProgress, {
      passive: true,
      signal,
    });
    window.addEventListener('resize', scheduleProgress, { signal });
    renderProgress();
  }

  if (typeof document$ !== 'undefined') {
    document$.subscribe(setupPage);
  } else if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupPage, { once: true });
  } else {
    setupPage();
  }
})();
