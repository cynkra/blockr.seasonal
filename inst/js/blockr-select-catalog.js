/* Blockr.SelectCatalog — the house control for CATEGORISED, DESCRIBED lists.
 *
 * A copy of blockr-select.js, deliberately. It is the better base than
 * SelectRich: it already has the search, the `onSearch` server-side hook,
 * `maxRendered`, multi mode, and the ResizeObserver this needs for the rail.
 * Duplicated rather than folded in, because Blockr.Select is used by every
 * block in the ecosystem and this is new. The two converge when the shared
 * layer moves to blockr.ui; until then a divergent copy is the cheap risk and
 * a refactor of the control everything depends on is the expensive one.
 *
 * What it adds over Blockr.Select:
 *
 *   option.group        a category heading; when no option has one, this
 *                       component behaves exactly like Blockr.Select
 *   option.description  a sentence, on its own line, searched like the label
 *   the rail            the category list beside the results, as a FACET:
 *                       its counts move with the query, so typing tells you
 *                       where the matches are before you choose where to look
 *
 * THE RAIL IS DECIDED BY MEASURED WIDTH, NOT BY THE CALLER. Below ~520px it
 * costs more than it gives: 150px of rail out of 350px of dropdown leaves the
 * descriptions ellipsised to a few words, and the descriptions are the whole
 * reason a list of 217 four-character codes is usable at all. Measured with a
 * ResizeObserver rather than a container query, because the design system
 * forbids those inside a block and the component already observes itself for
 * tag fitting.
 *
 * ---------------------------------------------------------------------------
 * HOW TO MERGE THIS BACK INTO Blockr.Select
 * ---------------------------------------------------------------------------
 *
 * This file is a fork of blockr.dplyr's inst/js/blockr-select.js, taken at the
 * point where that file was 1045 lines. It lives here, in blockr.seasonal,
 * because Blockr.Select is loaded by every block in the ecosystem and this was
 * new: a divergent copy is the cheap risk, a refactor of the control that
 * everything depends on is the expensive one. That trade expires. When the
 * shared layer moves to blockr.ui, the two become one file and this comment is
 * the instruction for doing it.
 *
 * THE MERGE IS ADDITIVE. With no option carrying `group` and none carrying
 * `description`, every path below is skipped and the behaviour is what
 * Blockr.Select does today. That is not an aspiration, it is what `scanShape()`
 * is for: the two flags are computed once when the options change, so a flat
 * list pays one boolean per render rather than a scan. Verified by measurement,
 * not by argument -- filtering 20,000 flat options costs 0.531 ms today and
 * 0.552 ms with these additions, and the whole feature is +2.8 KB gzipped of JS
 * and +1.0 KB of CSS.
 *
 * The nine changes, in the order you would replay them:
 *
 *   1. ACCESSORS. `optDesc()` and `optGroup()` beside the existing
 *      `optValue()` / `optLabel()`, plus `groupCounts()`. Pure additions; no
 *      existing caller can see them.
 *
 *   2. SHAPE FLAGS. `grouped` / `described`, set by `scanShape()` from the
 *      constructor and from both `setOptions()` and `updateOptions()`. This is
 *      the gate everything else sits behind. If you merge nothing else, merge
 *      this correctly: a `scanShape()` missing from a mutator is a list that
 *      silently stops grouping after its options are pushed from R.
 *
 *   3. SEARCH. `getFiltered()` also matches `optDesc()`, guarded by
 *      `described`. The description HAS to be in the index: in the X-13
 *      catalogue "trend" finds `dtr` and `ltt` only through their sentences,
 *      and a list of four-character codes whose search covers only the codes
 *      is a list you cannot search. `getFiltered()` also honours `scope`.
 *
 *   4. ROWS. `fillOptContent()` grows a two-line branch when an option has a
 *      description: name on top, sentence under, both ellipsised. The
 *      one-line shape (description AS the label, code trailing in mono) needs
 *      no code at all -- it is the existing `labelFirst` path, and it is what
 *      the seas series picker uses.
 *
 *   5. THE RAIL. `buildRail()` plus the panes branch in `renderDropdown()`.
 *      The rail is a FACET, not a tab bar: its counts are counts of the
 *      current search, so typing tells you where the matches are before you
 *      choose where to look; a group with no matches dims rather than leaving,
 *      or the rail reorders under the pointer mid-keystroke; and clicking
 *      scopes without closing. Counts are computed over the text match only,
 *      never over the current scope, or a scoped rail reads all zeroes and
 *      cannot be used to leave.
 *
 *   6. MEASURED WIDTH. `measure()` and the RAIL_AT threshold, hung off the
 *      ResizeObserver the component already ran for tag fitting. The rail is
 *      NOT a config flag: below ~520px it costs more than it gives, and a
 *      block author cannot know the width their panel will get. Keep it a
 *      measurement. A container query would be the obvious alternative and the
 *      design system forbids those inside a block.
 *
 *   7. RANKING. `scoreOpt()` and the sort in `getFiltered()`. Putting the
 *      description in the index (change 3) made every hit equal, which on the
 *      284 X-13 arguments is visibly wrong: "outlier" returned 46 rows with
 *      the outlier spec's own arguments at position 11. Ranks are name-exact,
 *      group-exact, name-prefix (including the last segment of a dotted
 *      name), name-substring, then description, ties by the original order.
 *      GROUPS are ordered by their best hit and rows within a group by their
 *      own score; sorting flat would interleave the headings and decouple the
 *      rail's counts from what is on screen. The rail itself keeps catalogue
 *      order. Gated at RANK_MAX = 5000 options, because at 20,000 the sort
 *      costs 0.86 ms a keystroke against 0.24 ms for a plain filter, and a
 *      list that size is a server-fed value picker whose order was chosen for
 *      a reason.
 *
 *   8. DISABLED. `optDisabled()`, a row class, no `data-value` on the row so
 *      no click path can select it, `aria-disabled`, and `step()` so the
 *      arrows skip it instead of parking on it. For options that exist but
 *      cannot be picked here.
 *
 *   9. CREATE. `config.allowCreate`, true or a validator returning the
 *      normalised value. A create row at the END of the list (at the top it
 *      would sit under the cursor while you are still typing), Enter commits
 *      it when nothing selectable is highlighted, and a tag with no option
 *      behind it renders a muted "typed" label, because `findOpt` finds
 *      nothing for it and otherwise it is indistinguishable from a known
 *      term. This is what the VALUE side needs and the picking side does not:
 *      regression.variables is two dozen known terms plus anything you date
 *      by hand.
 *
 * ONE BEHAVIOUR CHANGE TO DECIDE ON MERGE, and it is the only one:
 * `maxRendered` defaults to 1000 here against 200 in Blockr.Select. 200 is
 * right for a value filter, whose options come from a query and can be tens of
 * thousands; it is wrong for a fixed local catalogue, where "+17 more" under a
 * list of 217 is the component apologising for a limit that serves nobody.
 * Either keep 200 and have catalogue callers pass 1000, or make the default
 * conditional on `grouped`. Do not raise it globally: the lazy value pickers
 * depend on that cap. The genuinely server-backed path is untouched either way
 * -- `onSearch` and `serverTruncated` still produce "N values, type to search",
 * which says something true.
 *
 * THE CSS merges the same way. Everything above the marked section in
 * blockr-select-long.css is blockr-select.css unchanged; everything below is
 * new class names (`__group`, `__panes`, `__rail`, `__spec`, `__results`,
 * `__opt-desc`, `__option--two-line`) that no existing rule can collide with.
 * The one edit to an existing rule is `.blockr-select__dropdown--panes`, a
 * modifier that turns off the dropdown's own scrolling when the panes are
 * present -- without it there are three nested scroll containers, the
 * outermost wins, and dragging the results drags the rail with them.
 *
 * HOW TO KNOW THE MERGE DID NOT REGRESS: mount a flat list of two options with
 * no group and no description. It must render two rows, add no panes, and the
 * dropdown must keep its own `overflow-y: auto`. Then mount a grouped,
 * described list at 760px and at 380px: the first gets a rail, the second gets
 * headings only, and neither re-mounts when the width crosses the threshold.
 */
(() => {
  'use strict';

  // Helpers for {value, label} option objects
  /** @param {BlockrSelectOption} o @returns {string} */
  const optValue = (o) => typeof o === 'object' && o !== null ? o.value : o;
  /** @param {BlockrSelectOption} o @returns {string} */
  const optLabel = (o) => typeof o === 'object' && o !== null ? (o.label || '') : '';
  /** @param {BlockrSelectOption[]} opts @param {string} val */
  const findOpt = (opts, val) => opts.find(o => optValue(o) === val);

  const optDesc = (o) =>
    typeof o === 'object' && o !== null ? (o.description || '') : '';
  const optGroup = (o) =>
    typeof o === 'object' && o !== null ? (o.group || '') : '';
  /* An option that EXISTS but cannot be picked. Not the same as leaving it
   * out: the finder needs to say "shown above as Arima Model" rather than
   * offer the same thing twice, and a row that vanishes leaves the reader
   * wondering whether they mistyped. */
  const optDisabled = (o) =>
    typeof o === 'object' && o !== null ? !!o.disabled : false;

  /** Counts per group over a filtered set, keyed in the options' own order. */
  const groupCounts = (opts, hits) => {
    const order = [];
    const n = {};
    opts.forEach((o) => {
      const g = optGroup(o);
      if (!g) return;
      if (!(g in n)) { n[g] = 0; order.push(g); }
    });
    hits.forEach((o) => {
      const g = optGroup(o);
      if (g in n) n[g]++;
    });
    return { order: order, n: n };
  };
  /** Both facts, and `labelFirst` decides which one leads.
   *
   * A menu opened from a word has to lead with the word that was clicked. A
   * sentence printing `{label(@color)}` says "Actual Treatment", and a list
   * whose rows read "TRTA *Actual Treatment*" puts what the reader just
   * clicked in the muted half of the row and bolds a string that is nowhere
   * on screen. blockr.docs design-system/pinned-controls.md.
   *
   * @param {HTMLElement} el @param {BlockrSelectOption} o @param {boolean} [labelFirst]
   */
  const fillOptContent = (el, o, labelFirst) => {
    el.textContent = '';
    const val = optValue(o);
    const lbl = optLabel(o);
    const desc = optDesc(o);

    /* A DESCRIPTION GETS ITS OWN LINE. Ellipsised into a trailing slot a
     * sentence is decoration: at a dock panel's width you see four words of
     * sixty. The row costs ~44px instead of ~28px and the dropdown shows
     * seven instead of twelve, which is the real price of the pattern and is
     * worth paying for a list nobody can navigate by code alone. */
    if (desc) {
      el.className += ' blockr-select__option--two-line';
      const top = document.createElement('div');
      top.className = 'blockr-select__opt-head';
      const name = document.createElement('span');
      name.className = 'blockr-select__opt-name';
      name.textContent = (labelFirst && lbl) ? lbl : val;
      top.appendChild(name);
      const code = document.createElement('span');
      code.className = 'blockr-select__opt-label';
      code.textContent = (labelFirst && lbl) ? val : lbl;
      if (code.textContent) top.appendChild(code);
      el.appendChild(top);
      const sub = document.createElement('div');
      sub.className = 'blockr-select__opt-desc';
      sub.textContent = desc;
      el.appendChild(sub);
      el.title = desc;
      return;
    }

    const lead = (labelFirst && lbl) ? lbl : val;
    const trail = (labelFirst && lbl) ? val : lbl;
    el.appendChild(document.createTextNode(lead));
    // The element (or an ancestor) ellipsizes on overflow, so always offer
    // the full text on hover.
    el.title = lbl ? `${val} — ${lbl}` : val;
    if (trail) {
      const span = document.createElement('span');
      span.className = 'blockr-select__opt-label';
      span.textContent = trail;
      el.appendChild(span);
    }
  };

  /** Shorten a tag label from the MIDDLE.
   *
   * CSS can only ellipsize at the end, and for the values these controls carry
   * the distinguishing word is as often the last one as the first: "Xanomeline
   * High Dose" and "Xanomeline Low Dose" both end-ellipsize to "Xanomelin…".
   * Cutting the middle costs the same width and keeps both ends. The full value
   * stays on the tag's title.
   *
   * @param {string} value @param {number} cap @returns {string}
   */
  const midTruncate = (value, cap) => {
    if (!cap || value.length <= cap) return value;
    const head = Math.ceil((cap - 1) / 2);
    const tail = Math.floor((cap - 1) / 2);
    return value.slice(0, head) + '\u2026' + value.slice(value.length - tail);
  };

  /** How many tags fit on one row, given their measured widths.
   *
   * Split out from the DOM work because it is the part worth testing: the chip
   * has to fit too, so dropping a tag can force dropping the next one up when
   * the count goes from "+9" to "+10". Widths are in visual order and exclude
   * the gap, which is added between neighbours only.
   *
   * @param {number[]} widths @param {number} avail
   * @param {number} gap @param {number} chipWidth
   * @returns {number}
   */
  const fitCount = (widths, avail, gap, chipWidth) => {
    let used = 0;
    let shown = 0;
    for (let i = 0; i < widths.length; i++) {
      const w = widths[i] + (shown ? gap : 0);
      if (used + w > avail) break;
      used += w;
      shown++;
    }
    if (shown === widths.length) return shown;
    while (shown > 0 && used + gap + chipWidth > avail) {
      shown--;
      used -= widths[shown] + (shown ? gap : 0);
    }
    return shown;
  };

  /**
   * @param {HTMLElement} container
   * @param {BlockrSelectConfig} config
   * @param {'single' | 'multi'} mode
   */
  const createSelect = (container, config, mode) => {
    const id = Blockr.uid('bsel');
    const dropdownId = `${id}-lb`;

    // State
    let options = config.options || [];
    // Single mode only: opt out of the first-option fallback so '' means
    // "nothing selected" and survives setOptions(). Without it, any option
    // refresh silently picks option 0 — fine for a column picker, wrong
    // wherever an unrequested pick would change what the user is looking at.
    const allowEmpty = mode === 'single' && config.allowEmpty === true;
    // Headless: the dropdown IS the widget, anchored to something the caller
    // owns (a word in a block's sentence) instead of to a control this
    // builds. Same options, same tick, same search, same keyboard -- a menu
    // that drifts from the select is a second idiom nobody asked for.
    const headless = config.headless === true;
    const menuTitle = config.title || '';
    const labelFirst = config.labelFirst === true;
    // The select's own rule for when a list needs filtering, in one place.
    const searchAfter = config.searchAfter != null ? config.searchAfter : 8;
    const onClose = config.onClose || null;
    /** @type {string | string[]} string in 'single' mode, string[] in 'multi' */
    let selected = mode === 'multi'
      ? (config.selected || []).slice()
      : (config.selected != null
          ? config.selected
          : (allowEmpty || options.length === 0 ? '' : optValue(options[0])));
    const placeholder = config.placeholder || '';
    const reorderable = mode === 'multi' && config.reorderable !== false;
    // Keep the tags on one row and collapse the overflow into a "+N" chip,
    // instead of wrapping and growing the control a row per tag. Auto-generated
    // parameter bands (function block, code block) sit in a grid where the
    // tallest field sets the row height, so a wrapping select there is what
    // makes the whole band tall.
    const singleLine = mode === 'multi' && config.singleLine === true;
    // Tag labels longer than this are shortened in the middle (0 = never).
    const maxTagChars = mode === 'multi' && config.maxTagChars && config.maxTagChars > 0
      ? config.maxTagChars
      : 0;
    // Single-line only: the chip has been clicked, so the control wraps and
    // shows every tag until the click lands somewhere else. The dropdown lists
    // only UNselected options, so without this a tag past the first row could
    // be neither seen nor removed.
    let expanded = false;
    const onChange = config.onChange || null;
    const onOpen = config.onOpen || null;
    const onSearch = config.onSearch || null;
    // Cap how many options get DOM nodes per render. The full list stays
    // searchable; rendering 50K divs froze the tab on every open/keystroke.
    /* 200 is Blockr.Select's cap and it is right THERE: a value filter's
     * options come from a query and can be tens of thousands, so the list is
     * capped and the user is told to type. A grouped catalogue is a fixed
     * local array -- 217 rows is ~600 nodes, nothing -- and "+17 more" at the
     * bottom of a list of 217 is the component apologising for a limit that
     * serves no one. Server-backed callers still get the `serverTruncated`
     * path, which says something true: "N values, type to search". */
    const maxRendered = config.maxRendered || 1000;
    let truncated = 0;
    // Server-search mode (high-cardinality columns): the option list is a
    // server-truncated page; typing re-queries via onSearch instead of
    // relying on client-side filtering alone. Activated by setSearchInfo.
    let serverTruncated = false;
    let serverTotal = 0;
    /** @type {ReturnType<typeof setTimeout> | null} */
    let searchTimer = null;
    let loading = !!config.loading;
    let isOpen = false;
    let searchQuery = '';
    let highlightIdx = -1;
    /** Group the rail has scoped to, or null for all of them. */
    let scope = null;
    /* Computed when the options change, not on every render. A flat list then
     * pays one boolean per render instead of a scan, which is what makes
     * "costs nothing when unused" true rather than nearly true. */
    let grouped = false;
    let described = false;
    const scanShape = () => {
      grouped = false;
      described = false;
      for (let i = 0; i < options.length; i++) {
        if (!grouped && optGroup(options[i])) grouped = true;
        if (!described && optDesc(options[i])) described = true;
        if (grouped && described) break;
      }
    };
    /** Whether the dropdown is wide enough to spend 150px on a rail. */
    let wide = false;
    const RAIL_AT = 520;
    let destroyed = false;

    // Drag state (multi only)
    /** @type {string | null} */
    let dragValue = null;
    /** @type {Element | null} */
    let dragOverTag = null;
    /** @type {'before' | 'after' | null} */
    let dragSide = null;

    // DOM
    const root = document.createElement('div');
    root.className = `blockr-select blockr-select--${mode}`;
    if (singleLine) root.classList.add('blockr-select--single-line');
    if (headless) root.classList.add('blockr-select--headless');
    root.setAttribute('role', 'combobox');
    root.setAttribute('aria-expanded', 'false');
    root.setAttribute('aria-haspopup', 'listbox');
    root.setAttribute('aria-owns', dropdownId);

    const control = document.createElement('div');
    control.className = 'blockr-select__control';

    // Mode-correlated: tagsEl is set iff mode === 'multi', valueEl iff
    // 'single'; every use is behind the matching mode check.
    /** @type {HTMLDivElement} */
    let tagsEl = /** @type {any} */ (null);
    /** @type {HTMLSpanElement} */
    let valueEl = /** @type {any} */ (null);

    /** @type {HTMLSpanElement} */
    let moreEl = /** @type {any} */ (null);

    if (mode === 'multi') {
      tagsEl = document.createElement('div');
      tagsEl.className = 'blockr-select__tags';
      control.appendChild(tagsEl);
    } else {
      valueEl = document.createElement('span');
      valueEl.className = 'blockr-select__value';
      control.appendChild(valueEl);
    }

    const searchInput = document.createElement('input');
    searchInput.type = 'text';
    searchInput.className = 'blockr-select__search';
    searchInput.setAttribute('aria-autocomplete', 'list');
    searchInput.setAttribute('aria-controls', dropdownId);
    searchInput.setAttribute('autocomplete', 'off');
    searchInput.setAttribute('autocorrect', 'off');
    searchInput.setAttribute('autocapitalize', 'off');
    searchInput.setAttribute('spellcheck', 'false');
    if (mode === 'multi') {
      searchInput.setAttribute('placeholder', placeholder);
      tagsEl.appendChild(searchInput);
    } else {
      control.appendChild(searchInput);
    }

    if (mode === 'single') {
      const arrow = document.createElement('span');
      arrow.className = 'blockr-select__arrow';
      arrow.innerHTML = Blockr.icons.chevron;
      control.appendChild(arrow);
    }

    const dropdown = document.createElement('div');
    dropdown.className = 'blockr-select__dropdown';
    dropdown.id = dropdownId;
    dropdown.setAttribute('role', 'listbox');

    // In headless mode the control is never shown, so it is never mounted;
    // `searchInput` moves into the dropdown's head below and `valueEl` simply
    // renders into a detached node.
    if (!headless) root.appendChild(control);
    container.appendChild(root);

    // Head of a headless dropdown: the role's name, and the filter box past
    // the same threshold the select uses elsewhere. Everything after
    // `headEnd` is options, and only that part is cleared on re-render, so a
    // keystroke cannot move the input the user is typing into.
    /** @type {Comment | null} */
    let headEnd = null;
    if (headless) {
      if (menuTitle) {
        const t = document.createElement('div');
        t.className = 'blockr-select__menu-title';
        t.textContent = menuTitle;
        dropdown.appendChild(t);
      }
      // Always mounted, because focus is what makes the arrows, Enter and
      // type-ahead work; only shown once the list is long enough to need
      // filtering. A short menu still filters as you type, which is what a
      // native menu does.
      searchInput.className += (options.length > searchAfter)
        ? ' blockr-select__search--menu'
        : ' blockr-select__search--menu blockr-select__search--offscreen';
      searchInput.setAttribute('placeholder', config.searchPlaceholder || 'Filter');
      dropdown.appendChild(searchInput);
      headEnd = document.createComment('opts');
      dropdown.appendChild(headEnd);
    }

    // Portal: dropdown lives on document.body while open so it escapes any
    // clipping / paint-containment / stacking-context ancestors (Dockview
    // panels, offcanvas, modals, …). See blockr.design/open/blockr-select-portal.

    const computePosition = () => {
      // Anchored to the caller's element when there is no control of our own.
      const r = (config.anchor || root).getBoundingClientRect();
      const dropH = dropdown.offsetHeight || 240;
      const spaceBelow = window.innerHeight - r.bottom - 8;
      const flipAbove = spaceBelow < dropH && r.top > dropH;

      dropdown.style.position = 'fixed';
      dropdown.style.bottom   = 'auto';
      if (headless) {
        // A word is not a control: the panel sizes to its own content, and
        // has to be pulled back inside the viewport rather than lining up.
        // `right` is 0 in the stylesheet (a dropdown normally spans its
        // control), which would stretch a fixed box to the window edge and
        // make every menu exactly max-width wide.
        dropdown.style.right = 'auto';
        dropdown.style.width = '';
        dropdown.style.minWidth = (config.minWidth || 190) + 'px';
        dropdown.style.maxWidth = (config.maxWidth || 320) + 'px';
        const w = dropdown.offsetWidth || 190;
        dropdown.style.left = Math.max(8, Math.min(r.left,
          document.documentElement.clientWidth - w - 8)) + 'px';
      } else {
        dropdown.style.width = r.width + 'px';
        dropdown.style.left  = r.left + 'px';
      }

      if (flipAbove) {
        dropdown.style.top = (r.top - dropH - 4) + 'px';
        root.classList.add('blockr-select--above');
      } else {
        dropdown.style.top = (r.bottom + 4) + 'px';
        root.classList.remove('blockr-select--above');
      }
    };

    const onScrollOrResize = () => { if (isOpen) computePosition(); };

    // --- Rendering ---

    /* HOW WELL DOES THIS OPTION MATCH? Lower is better, -1 is no match.
     *
     * Adding the description to the index made every hit equal, and on the
     * 284 X-13 arguments that is visibly wrong: "outlier" returns 46 hits and
     * the outlier spec's own arguments start at position 11, behind a dozen
     * options whose prose happens to mention outliers. The name is what the
     * reader typed at; the description is why the row is here at all.
     */
    const RANK_EXACT = 0, RANK_GROUP = 1, RANK_PREFIX = 2,
          RANK_SUB = 3, RANK_DESC = 4;
    const scoreOpt = (opt, q) => {
      const val = String(optValue(opt)).toLowerCase();
      const lbl = optLabel(opt).toLowerCase();
      if (val === q || lbl === q) return RANK_EXACT;
      /* NAMING A GROUP ASKS FOR ITS MEMBERS. Typing "outlier" against the
       * X-13 arguments should lead with the outlier spec, whose arguments
       * are called `types` and `critical` and so match nothing but their
       * group. Without this the list leads with `history.outlier`, which
       * matches by name and is not what was asked for. */
      if (grouped && optGroup(opt).toLowerCase() === q) return RANK_GROUP;
      if (val.indexOf(q) === 0 || lbl.indexOf(q) === 0) return RANK_PREFIX;
      // A dotted name ranks on its last segment too, so "variables" reaches
      // `regression.variables` as a prefix rather than as a substring.
      const seg = val.slice(val.lastIndexOf('.') + 1);
      if (seg.indexOf(q) === 0) return RANK_PREFIX;
      if (val.indexOf(q) >= 0 || lbl.indexOf(q) >= 0) return RANK_SUB;
      if (described && optDesc(opt).toLowerCase().indexOf(q) >= 0) return RANK_DESC;
      return -1;
    };

    /* Sorting is NOT free and is not always wanted. At 20,000 options a
     * score-and-sort costs 0.86 ms per keystroke against 0.24 ms for a plain
     * filter, and a list that large is a lazily-loaded value picker whose
     * order came from the server for a reason. Ranking is for catalogues. */
    const RANK_MAX = 5000;

    /* CREATE MODE. `config.allowCreate` is true, or a validator taking the
     * typed query and returning the normalised value (or null to refuse).
     * The picking side never needs it -- nobody invents an argument name --
     * but the VALUE side does: regression.variables is two dozen known terms
     * plus anything you date by hand, `ao1951.may`, `rp1988.jan-1988.dec`.
     * A control that only offers the known terms cannot express the second
     * half of its own vocabulary. */
    const allowCreate = config.allowCreate || false;
    const normaliseNew = (q) => {
      if (!allowCreate || !q) return null;
      const v = typeof allowCreate === 'function' ? allowCreate(q) : q.trim();
      if (!v) return null;
      // Never "create" something that already exists; that is a selection.
      return findOpt(options, v) ? null : v;
    };

    const getFiltered = () => {
      const q = searchQuery.toLowerCase();
      /** @type {BlockrSelectOption[]} */
      const result = [];
      /** @type {{opt: BlockrSelectOption, s: number, i: number}[]} */
      const scored = [];
      const ranking = !!q && options.length <= RANK_MAX;
      truncated = 0;
      for (let i = 0; i < options.length; i++) {
        const opt = options[i];
        const val = optValue(opt);
        if (mode === 'multi' && selected.indexOf(val) >= 0) continue;
        if (grouped && scope && optGroup(opt) !== scope) continue;
        let s = 0;
        if (q) {
          s = scoreOpt(opt, q);
          if (s < 0) continue;
        }
        if (ranking) { scored.push({ opt: opt, s: s, i: i }); continue; }
        if (result.length < maxRendered) result.push(opt);
        else truncated++;
      }
      if (!ranking) return result;

      /* GROUP ORDER FOLLOWS THE BEST HIT IN EACH GROUP; rows inside a group
       * follow their score. Sorting the whole list flat would be simpler and
       * would break the thing that makes this control worth having: the
       * headings would interleave and repeat, and the rail's counts would
       * stop corresponding to what is on screen. The RAIL itself keeps
       * catalogue order, because a facet that reorders while you type is the
       * one thing a facet must never do. */
      if (grouped) {
        const best = {};
        scored.forEach((r) => {
          const g = optGroup(r.opt);
          if (!(g in best) || r.s < best[g]) best[g] = r.s;
        });
        const firstAt = {};
        scored.forEach((r) => {
          const g = optGroup(r.opt);
          if (!(g in firstAt)) firstAt[g] = r.i;
        });
        scored.sort((a, b) => {
          const ga = optGroup(a.opt), gb = optGroup(b.opt);
          if (ga !== gb) return (best[ga] - best[gb]) || (firstAt[ga] - firstAt[gb]);
          return (a.s - b.s) || (a.i - b.i);
        });
      } else {
        scored.sort((a, b) => (a.s - b.s) || (a.i - b.i));
      }

      for (let k = 0; k < scored.length; k++) {
        if (result.length < maxRendered) result.push(scored[k].opt);
        else truncated++;
      }
      return result;
    };

    // Everything after `headEnd` is options. In headless mode the title and
    // the filter box sit before it and survive a re-render; without this the
    // input would be re-created (or moved, which blurs it) on every keystroke.
    const clearOptions = () => {
      if (!headEnd) { dropdown.innerHTML = ''; return; }
      while (headEnd.nextSibling) dropdown.removeChild(headEnd.nextSibling);
    };

    /* THE RAIL IS A FACET, NOT A TAB BAR: the number beside each group is
     * the count of the CURRENT SEARCH, so typing "trend" says the matches are
     * in seats and x11 before you have decided where to look. A group with no
     * matches DIMS rather than leaving the list, or the rail reorders under
     * the pointer while you are still typing. Idea from the seas argument
     * finder, `_scratch/seas-ui/finder.html`. */
    const buildRail = (hits) => {
      const rail = document.createElement('div');
      rail.className = 'blockr-select__rail';

      // Counts are over the TEXT match only, not over the current scope: a
      // scoped rail whose other rows all read 0 cannot be used to leave.
      const q = searchQuery.toLowerCase();
      const textHits = options.filter((o) => !q ||
        String(optValue(o)).toLowerCase().indexOf(q) >= 0 ||
        optLabel(o).toLowerCase().indexOf(q) >= 0 ||
        optDesc(o).toLowerCase().indexOf(q) >= 0);
      const { order, n } = groupCounts(options, textHits);

      const row = (label, count, on, value) => {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'blockr-select__spec' + (on ? ' is-on' : '') +
          (count ? '' : ' is-dim');
        b.setAttribute('data-group', value == null ? '' : value);
        const nm = document.createElement('span');
        nm.textContent = label;
        const ct = document.createElement('span');
        ct.className = 'blockr-select__spec-count';
        ct.textContent = String(count);
        b.appendChild(nm);
        b.appendChild(ct);
        return b;
      };

      rail.appendChild(row('all', textHits.length, scope === null, null));
      order.forEach((g) => rail.appendChild(row(g, n[g], scope === g, g)));
      return rail;
    };

    /* The create row sits at the END of whatever is on screen. At the top it
     * would sit under the cursor while you are still typing the thing you are
     * trying to find. It has to be appended from BOTH render paths: the case
     * where nothing matches is the case where it matters most, and that path
     * returns early. */
    const appendCreateRow = (host) => {
      const pending = normaliseNew(searchQuery);
      if (!pending) return;
      if (mode === 'multi' && selected.indexOf(pending) >= 0) return;
      const add = document.createElement('div');
      add.className = 'blockr-select__option blockr-select__create';
      add.setAttribute('role', 'option');
      add.setAttribute('data-create', pending);
      const lead = document.createElement('span');
      lead.className = 'blockr-select__create-lead';
      lead.textContent = 'Add';
      const v = document.createElement('span');
      v.className = 'blockr-select__create-value';
      v.textContent = pending;
      add.appendChild(lead);
      add.appendChild(v);
      host.appendChild(add);
    };

    const renderDropdown = () => {
      // A scope that no longer has matches would show an empty pane beside a
      // rail full of numbers. Drop it and show everything the query found.
      if (scope !== null) {
        const q = searchQuery.toLowerCase();
        const any = options.some((o) => optGroup(o) === scope && (!q ||
          String(optValue(o)).toLowerCase().indexOf(q) >= 0 ||
          optLabel(o).toLowerCase().indexOf(q) >= 0 ||
          optDesc(o).toLowerCase().indexOf(q) >= 0));
        if (!any) scope = null;
      }
      const filtered = getFiltered();
      clearOptions();

      if (loading) {
        const empty = document.createElement('div');
        empty.className = 'blockr-select__empty';
        empty.textContent = 'Loading…';
        dropdown.appendChild(empty);
        highlightIdx = -1;
        return;
      }

      if (filtered.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'blockr-select__empty';
        empty.textContent = searchQuery
          ? 'No matches'
          : (mode === 'multi' ? 'All selected' : 'No options');
        dropdown.appendChild(empty);
        appendCreateRow(dropdown);
        highlightIdx = -1;
        return;
      }

      if (highlightIdx >= filtered.length) highlightIdx = filtered.length - 1;
      if (highlightIdx < 0 && filtered.length > 0) highlightIdx = 0;
      if (highlightIdx >= 0 && optDisabled(filtered[highlightIdx])) {
        highlightIdx = step(filtered, highlightIdx, 1);
      }

      /* WHERE THE OPTIONS GO. Ungrouped, straight into the dropdown, which is
       * what Blockr.Select does. Grouped and narrow, into a single column with
       * headings. Grouped and wide, into the right pane with the rail beside
       * it. One component, three layouts, and the caller picks none of them. */
      let host = dropdown;
      dropdown.classList.remove('blockr-select__dropdown--panes');
      if (grouped && wide) {
        /* THE DROPDOWN STOPS SCROLLING WHEN THE PANES START. Three nested
         * scroll containers and the outermost wins, which is why dragging
         * the results also dragged the rail: the panes never reached their
         * own limit because the dropdown clipped first. */
        dropdown.classList.add('blockr-select__dropdown--panes');
        const panes = document.createElement('div');
        panes.className = 'blockr-select__panes';
        panes.appendChild(buildRail(filtered));
        host = document.createElement('div');
        host.className = 'blockr-select__results';
        panes.appendChild(host);
        dropdown.appendChild(panes);
      }

      let lastGroup = null;
      for (let i = 0; i < filtered.length; i++) {
        const opt = filtered[i];
        const val = optValue(opt);
        const grp = optGroup(opt);
        if (grouped && grp && grp !== lastGroup) {
          lastGroup = grp;
          const h = document.createElement('div');
          h.className = 'blockr-select__group';
          const gn = document.createElement('span');
          gn.textContent = grp;
          h.appendChild(gn);
          host.appendChild(h);
        }
        const div = document.createElement('div');
        const off = optDisabled(opt);
        div.className = 'blockr-select__option';
        if (off) div.className += ' blockr-select__option--disabled';
        if (i === highlightIdx) div.className += ' blockr-select__option--highlighted';
        if (mode === 'single' && val === selected) div.className += ' blockr-select__option--selected';
        div.setAttribute('role', 'option');
        div.setAttribute('id', `${id}-opt-${i}`);
        div.setAttribute('aria-selected', (mode === 'single' && val === selected) ? 'true' : 'false');
        div.setAttribute('aria-disabled', off ? 'true' : 'false');
        // No data-value on a disabled row, so the click handler cannot
        // select it by accident from any path.
        if (!off) div.setAttribute('data-value', val);
        fillOptContent(div, opt, labelFirst);
        host.appendChild(div);
      }

      appendCreateRow(host);

      if (serverTruncated) {
        const more = document.createElement('div');
        more.className = 'blockr-select__empty';
        more.textContent = `${serverTotal.toLocaleString()} values — type to search`;
        dropdown.appendChild(more);
      } else if (truncated > 0) {
        const more = document.createElement('div');
        more.className = 'blockr-select__empty';
        more.textContent = `+${truncated.toLocaleString()} more — type to narrow`;
        dropdown.appendChild(more);
      }

      if (highlightIdx >= 0) {
        searchInput.setAttribute('aria-activedescendant', `${id}-opt-${highlightIdx}`);
      }
    };

    const renderValue = () => {
      if (mode !== 'single') return;
      // Headless has no control to render into, and writing the search
      // placeholder here would wipe the menu's "Filter" prompt.
      if (headless) return;
      if (selected) {
        const opt = findOpt(options, /** @type {string} */ (selected));
        // labelFirst REACHES THE VALUE DISPLAY TOO. The design-system rule
        // this file already cites -- do not bold a string that is nowhere on
        // screen -- argues for matching the rows, not for value-first always.
        // With a catalogue the row reads "Seasonally adjusted (final) series
        // | final", and the closed control has to read the same way round.
        if (opt) { fillOptContent(valueEl, opt, labelFirst); } else { valueEl.textContent = /** @type {string} */ (selected); valueEl.title = /** @type {string} */ (selected); }
        // valueEl has pointer-events: none, so its title never triggers —
        // hover happens on the control.
        control.title = valueEl.title;
        valueEl.classList.remove('blockr-select__value--placeholder');
        searchInput.setAttribute('placeholder', '');
      } else {
        valueEl.textContent = placeholder;
        valueEl.title = '';
        control.title = '';
        valueEl.classList.add('blockr-select__value--placeholder');
        searchInput.setAttribute('placeholder', placeholder);
      }
    };

    const renderTags = () => {
      if (mode !== 'multi') return;
      // Remove only tag elements, preserve the search input
      tagsEl.querySelectorAll('.blockr-select__tag').forEach(t => t.remove());
      for (let i = 0; i < selected.length; i++) {
        const val = selected[i];
        const tag = document.createElement('span');
        tag.className = 'blockr-select__tag';
        tag.setAttribute('data-value', val);
        if (reorderable) tag.setAttribute('draggable', 'true');

        const label = document.createElement('span');
        label.className = 'blockr-select__tag-label';
        // Match the dropdown option and single-select value display: show the
        // value in normal font with the option's label muted on the side
        // (`.blockr-select__opt-label`). Unnamed options fall back to bare value.
        const opt = findOpt(options, val);
        if (maxTagChars && val.length > maxTagChars) {
          const lbl = opt ? optLabel(opt) : '';
          label.textContent = midTruncate(val, maxTagChars);
          label.title = lbl ? `${val} \u2014 ${lbl}` : val;
        } else if (opt) {
          fillOptContent(label, opt, labelFirst);
        } else {
          /* A value with no option behind it was TYPED. Say so, muted, in the
           * slot the option's label would have used -- `findOpt` returns
           * nothing for it, and a bare tag looks identical to a known term. */
          label.textContent = val;
          label.title = val;
          if (allowCreate) {
            const mark = document.createElement('span');
            mark.className = 'blockr-select__opt-label';
            mark.textContent = 'typed';
            label.appendChild(mark);
          }
        }
        tag.appendChild(label);

        const removeBtn = document.createElement('button');
        removeBtn.type = 'button';
        removeBtn.className = 'blockr-select__tag-remove';
        removeBtn.setAttribute('aria-label', `Remove ${val}`);
        removeBtn.setAttribute('tabindex', '-1');
        removeBtn.innerHTML = Blockr.icons.remove;
        tag.appendChild(removeBtn);

        tagsEl.insertBefore(tag, searchInput);
      }
      searchInput.setAttribute('placeholder', selected.length === 0 ? placeholder : '');
    };

    /* Hide the tags past the first row and count them on the chip.
     *
     * Runs after every render and from a ResizeObserver, so widening the block
     * gives tags back without anything else having to notice. A zero width
     * means the control is not laid out yet (a deferred dock panel, a hidden
     * tab): leave every tag visible and let the observer's first delivery do
     * the fit, rather than measuring against nothing and hiding all of them.
     */
    const fitTags = () => {
      if (!singleLine || destroyed) return;
      const tags = /** @type {HTMLElement[]} */ (
        Array.from(tagsEl.querySelectorAll('.blockr-select__tag'))
      );
      tags.forEach(t => t.classList.remove('blockr-select__tag--hidden'));
      if (moreEl) moreEl.style.display = 'none';
      if (!tags.length || expanded) return;

      const avail = tagsEl.clientWidth;
      if (!avail) return;

      const gap = parseFloat(getComputedStyle(tagsEl).columnGap) || 3;
      // While the dropdown is open the search input is back in flow and needs
      // its min-width, so the tags get that much less room.
      const reserve = isOpen ? 40 + gap : 0;

      if (!moreEl) {
        moreEl = document.createElement('span');
        moreEl.className = 'blockr-select__more';
        moreEl.setAttribute('aria-hidden', 'true');
      }
      // Measure the chip at its widest possible count: the count can only
      // shrink as tags are dropped, never grow past the total.
      moreEl.textContent = `+${tags.length}`;
      moreEl.style.display = '';
      if (moreEl.parentElement !== tagsEl) tagsEl.insertBefore(moreEl, searchInput);
      const chipWidth = moreEl.getBoundingClientRect().width;

      const widths = tags.map(t => t.getBoundingClientRect().width);
      const shown = fitCount(widths, avail - reserve, gap, chipWidth);

      if (shown >= tags.length) {
        moreEl.style.display = 'none';
        return;
      }
      const hidden = tags.slice(shown);
      hidden.forEach(t => t.classList.add('blockr-select__tag--hidden'));
      moreEl.textContent = `+${hidden.length}`;
      moreEl.title = hidden
        .map(t => t.getAttribute('data-value'))
        .filter(Boolean)
        .join(', ');
    };

    const render = () => {
      if (mode === 'single') renderValue();
      if (mode === 'multi') renderTags();
      if (mode === 'multi') fitTags();
      if (isOpen) renderDropdown();
    };

    // --- Open / close ---

    const open = () => {
      if (isOpen || destroyed) return;
      isOpen = true;
      searchQuery = '';
      searchInput.value = '';
      highlightIdx = 0;

      if (dropdown.parentElement !== document.body) {
        document.body.appendChild(dropdown);
      }
      dropdown.style.display = 'block';

      root.classList.add('blockr-select--open');
      root.setAttribute('aria-expanded', 'true');
      // The search input is back in flow now, so the row is narrower.
      if (mode === 'multi') fitTags();

      if (mode === 'single' && !headless) {
        valueEl.style.display = 'none';
        searchInput.style.width = '';
        searchInput.setAttribute('placeholder', /** @type {string} */ (selected) || placeholder);
      }

      renderDropdown();
      computePosition();
      window.addEventListener('scroll', onScrollOrResize, { capture: true, passive: true });
      window.addEventListener('resize', onScrollOrResize, { passive: true });
      searchInput.focus();

      if (onOpen) onOpen();
    };

    const close = () => {
      if (!isOpen) return;
      isOpen = false;
      searchQuery = '';
      searchInput.value = '';

      window.removeEventListener('scroll', onScrollOrResize, { capture: true });
      window.removeEventListener('resize', onScrollOrResize);

      dropdown.style.display = '';

      root.classList.remove('blockr-select--open', 'blockr-select--above');
      root.setAttribute('aria-expanded', 'false');
      searchInput.removeAttribute('aria-activedescendant');
      if (mode === 'multi') fitTags();

      if (mode === 'single') {
        valueEl.style.display = '';
        searchInput.style.width = '';
        searchInput.setAttribute('placeholder', '');
      }

      dropdown.innerHTML = '';
      // Last, and after the DOM is settled: a headless caller tears the whole
      // widget down from here.
      if (onClose) onClose();
    };

    const toggle = () => { isOpen ? close() : open(); };

    // --- Selection ---

    /** @param {string} value */
    const selectOption = (value) => {
      if (mode === 'single') {
        const changed = selected !== value;
        selected = value;
        close();
        render();
        if (changed && onChange) onChange(selected);
      } else {
        if (selected.indexOf(value) < 0) {
          /** @type {string[]} */ (selected).push(value);
          searchQuery = '';
          searchInput.value = '';
          highlightIdx = 0;
          render();
          renderDropdown();
          if (onChange) onChange(selected.slice());
        }
      }
    };

    /** @param {string} value */
    const removeTag = (value) => {
      const idx = selected.indexOf(value);
      if (idx >= 0) {
        /** @type {string[]} */ (selected).splice(idx, 1);
        render();
        if (isOpen) renderDropdown();
        if (onChange) onChange(selected.slice());
      }
    };

    // --- Event handlers ---

    /** @param {MouseEvent} e */
    const onControlClick = (e) => {
      if (/** @type {Element} */ (e.target).closest('.blockr-select__tag-remove')) return;
      if (mode === 'single') {
        toggle();
      } else {
        if (!isOpen) open();
        searchInput.focus();
      }
    };

    /** @param {MouseEvent} e */
    const onDropdownClick = (e) => {
      const spec = /** @type {Element} */ (e.target).closest('.blockr-select__spec');
      if (spec) {
        // SCOPING IS NOT SELECTING. The rail narrows the list; it never
        // closes the dropdown, and clicking the scope again leaves it.
        const g = spec.getAttribute('data-group') || null;
        scope = (scope === g) ? null : g;
        highlightIdx = 0;
        renderDropdown();
        return;
      }
      const optEl = /** @type {Element} */ (e.target).closest('.blockr-select__option');
      if (optEl) {
        const made = optEl.getAttribute('data-create');
        if (made != null) { selectOption(made); return; }
        const val = optEl.getAttribute('data-value');
        if (val != null) selectOption(val);
      }
    };

    /** @param {MouseEvent} e */
    const onTagRemoveClick = (e) => {
      const btn = /** @type {Element} */ (e.target).closest('.blockr-select__tag-remove');
      if (!btn) return;
      const tag = btn.closest('.blockr-select__tag');
      if (tag) {
        const val = tag.getAttribute('data-value');
        if (val != null) removeTag(val);
      }
      e.stopPropagation();
    };

    /* The "+N" chip: show the rest rather than open the dropdown, which in
     * multi mode lists only what is NOT selected. */
    /** @param {MouseEvent} e */
    const onMoreClick = (e) => {
      if (!singleLine) return;
      if (!(/** @type {Element} */ (e.target).closest('.blockr-select__more'))) return;
      e.stopPropagation();
      expanded = true;
      root.classList.add('blockr-select--expanded');
      fitTags();
    };

    const collapse = () => {
      if (!expanded) return;
      expanded = false;
      root.classList.remove('blockr-select--expanded');
      fitTags();
    };

    const onSearchInput = () => {
      searchQuery = searchInput.value;
      highlightIdx = 0;
      if (!isOpen) open();
      else renderDropdown();
      // Server-search mode: re-query after the user pauses typing. The
      // client-side filter above gives instant feedback on the loaded page;
      // the server response then replaces the option list via updateOptions.
      if (serverTruncated && onSearch) {
        if (searchTimer) clearTimeout(searchTimer);
        searchTimer = setTimeout(() => onSearch(searchQuery), 250);
      }
    };

    /* Arrows land on something you can pick. A disabled row is skipped
     * rather than made unreachable-but-highlightable, which is how you get a
     * cursor that appears stuck. */
    const step = (list, from, dir) => {
      const n = list.length;
      if (!n) return -1;
      let i = from;
      for (let k = 0; k < n; k++) {
        i = (i + dir + n) % n;
        if (!optDisabled(list[i])) return i;
      }
      return -1;
    };

    /** @param {KeyboardEvent} e */
    const onSearchKeydown = (e) => {
      const filtered = getFiltered();
      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault();
          if (!isOpen) { open(); return; }
          highlightIdx = step(filtered, highlightIdx, 1);
          renderDropdown();
          scrollHighlightIntoView();
          break;
        case 'ArrowUp':
          e.preventDefault();
          if (!isOpen) { open(); return; }
          highlightIdx = step(filtered, highlightIdx, -1);
          renderDropdown();
          scrollHighlightIntoView();
          break;
        case 'Enter': {
          e.preventDefault();
          if (!isOpen) { open(); return; }
          const hit = highlightIdx >= 0 && highlightIdx < filtered.length
            ? filtered[highlightIdx] : null;
          if (hit && !optDisabled(hit)) { selectOption(optValue(hit)); break; }
          // Nothing selectable under the cursor: if the typed text is a legal
          // new value, Enter is how you commit it.
          const made = normaliseNew(searchQuery);
          if (made) selectOption(made);
          break;
        }
        case 'Escape':
          e.preventDefault();
          close();
          root.focus();
          break;
        case 'Backspace':
          if (mode === 'multi' && searchInput.value === '' && selected.length > 0) {
            removeTag(selected[selected.length - 1]);
          }
          break;
        case 'Tab':
          close();
          break;
      }
    };

    const scrollHighlightIntoView = () => {
      dropdown.querySelector('.blockr-select__option--highlighted')
        ?.scrollIntoView({ block: 'nearest' });
    };

    /** @param {MouseEvent} e */
    const onDocumentClick = (e) => {
      if (root.contains(/** @type {Node | null} */ (e.target)) || dropdown.contains(/** @type {Node | null} */ (e.target))) return;
      // The anchor is not outside. A click on it is the caller's toggle, and
      // closing here first would have it re-open on the same click.
      if (config.anchor && config.anchor.contains(/** @type {Node | null} */ (e.target))) return;
      collapse();
      close();
    };

    /** @param {KeyboardEvent} e */
    const onRootKeydown = (e) => {
      if (e.target === root && !isOpen) {
        if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowDown' || e.key === 'ArrowUp') {
          e.preventDefault();
          open();
        }
      }
    };

    // --- Drag and drop (multi mode) ---

    const clearDropIndicators = () => {
      if (!tagsEl) return;
      tagsEl.querySelectorAll('.blockr-select__tag--drop-before, .blockr-select__tag--drop-after')
        .forEach(el => el.classList.remove('blockr-select__tag--drop-before', 'blockr-select__tag--drop-after'));
    };

    /** @param {DragEvent} e */
    const onDragStart = (e) => {
      const tag = /** @type {Element} */ (e.target).closest('.blockr-select__tag');
      if (!tag) return;
      dragValue = tag.getAttribute('data-value');
      /** @type {DataTransfer} */ (e.dataTransfer).effectAllowed = 'move';
      /** @type {DataTransfer} */ (e.dataTransfer).setData('text/plain', /** @type {string} */ (dragValue));
      tag.classList.add('blockr-select__tag--dragging');
    };

    /** @param {DragEvent} e */
    const onDragOver = (e) => {
      if (dragValue == null) return;
      e.preventDefault();
      /** @type {DataTransfer} */ (e.dataTransfer).dropEffect = 'move';

      const tag = /** @type {Element} */ (e.target).closest('.blockr-select__tag');
      if (!tag || tag.getAttribute('data-value') === dragValue) {
        clearDropIndicators();
        return;
      }

      const rect = tag.getBoundingClientRect();
      const mid = rect.left + rect.width / 2;
      const side = e.clientX < mid ? 'before' : 'after';

      if (tag !== dragOverTag || side !== dragSide) {
        clearDropIndicators();
        dragOverTag = tag;
        dragSide = side;
        tag.classList.add(`blockr-select__tag--drop-${side}`);
      }
    };

    const onDragEnd = () => {
      clearDropIndicators();
      tagsEl?.querySelectorAll('.blockr-select__tag--dragging')
        .forEach(el => el.classList.remove('blockr-select__tag--dragging'));
      dragValue = null;
      dragOverTag = null;
      dragSide = null;
    };

    /** @param {DragEvent} e */
    const onDrop = (e) => {
      e.preventDefault();
      if (dragValue == null || !dragOverTag) { onDragEnd(); return; }

      const targetVal = /** @type {string} */ (dragOverTag.getAttribute('data-value'));
      const fromIdx = selected.indexOf(dragValue);
      let toIdx = selected.indexOf(targetVal);
      if (fromIdx < 0 || toIdx < 0 || fromIdx === toIdx) { onDragEnd(); return; }

      /** @type {string[]} */ (selected).splice(fromIdx, 1);
      toIdx = selected.indexOf(targetVal);
      const insertIdx = dragSide === 'after' ? toIdx + 1 : toIdx;
      /** @type {string[]} */ (selected).splice(insertIdx, 0, dragValue);

      onDragEnd();
      render();
      if (onChange) onChange(selected.slice());
    };

    // --- Bind events ---

    control.addEventListener('click', onControlClick);
    dropdown.addEventListener('click', onDropdownClick);
    searchInput.addEventListener('input', onSearchInput);
    searchInput.addEventListener('keydown', onSearchKeydown);
    document.addEventListener('click', onDocumentClick, true);
    root.addEventListener('keydown', onRootKeydown);

    if (mode === 'multi') {
      control.addEventListener('click', onTagRemoveClick);
      if (singleLine) control.addEventListener('click', onMoreClick, true);
      if (reorderable && tagsEl) {
        tagsEl.addEventListener('dragstart', onDragStart);
        tagsEl.addEventListener('dragover', onDragOver);
        tagsEl.addEventListener('dragend', onDragEnd);
        tagsEl.addEventListener('drop', onDrop);
      }
    }

    render();

    /* Re-fit on width changes: a dock panel resize, a grid reflow, or the
     * control's first layout after a deferred panel mounts. Observing the
     * control rather than the tags row keeps this out of a feedback loop:
     * hiding a tag changes the row's content, never the control's width. */
    /* THE RAIL APPEARS BY MEASUREMENT, not because a block asked for it.
     * Same observer as the tag fitting: one control, one layout decision,
     * taken from the width it actually has rather than from a media query
     * the design system does not allow inside a block. */
    const measure = () => {
      const w = control.getBoundingClientRect().width;
      const next = w >= RAIL_AT;
      if (next === wide) return false;
      wide = next;
      return true;
    };
    scanShape();
    measure();

    /** @type {ResizeObserver | null} */
    let resizeObs = null;
    if (typeof ResizeObserver !== 'undefined') {
      let pending = false;
      resizeObs = new ResizeObserver(() => {
        if (pending) return;
        pending = true;
        requestAnimationFrame(() => {
          pending = false;
          if (singleLine) fitTags();
          // Re-render only when the layout actually flips, never on every
          // pixel of a drag.
          if (measure() && isOpen) renderDropdown();
        });
      });
      resizeObs.observe(control);
    }

    // --- Public API ---

    return {
      el: root,

      // Headless callers own the opening: there is no control to click.
      open() { open(); },

      /**
       * @param {BlockrSelectOption[] | BlockrSelectOption | null | undefined} opts
       * @param {string | string[] | null} [sel]
       */
      setOptions(opts, sel) {
        options = Array.isArray(opts) ? opts : (opts != null ? [opts] : []);
        scanShape();
        const vals = options.map(optValue);
        if (mode === 'single') {
          if (sel != null && vals.indexOf(/** @type {string} */ (sel)) >= 0) {
            selected = sel;
          } else if (allowEmpty) {
            // '' survives, and a selection that is no longer among the options
            // CLEARS rather than sliding onto option 0. Omitting `sel` keeps a
            // still-valid selection instead of resetting it.
            selected = (sel == null &&
                        vals.indexOf(/** @type {string} */ (selected)) >= 0)
              ? selected
              : '';
          } else if (options.length > 0) {
            selected = optValue(options[0]);
          } else {
            selected = '';
          }
        } else {
          // A multi-select's selection is an array, but a caller may hand us a
          // scalar (e.g. a block constructed with `names_from = "y"`). Coerce to
          // an array so `.filter` never throws -- an unhandled throw here aborts
          // the rest of the Shiny message batch, which can drop later custom
          // messages (e.g. a chart's `drilldown-data`), leaving those blocks blank.
          const src = sel != null ? sel : selected;
          const arr = Array.isArray(src)
            ? src
            : (src != null && src !== '' ? [src] : []);
          selected = arr.filter(v => vals.indexOf(v) >= 0);
        }
        render();
        if (isOpen) renderDropdown();
      },

      getValue() {
        return mode === 'single' ? (selected || '') : selected.slice();
      },

      // Swap the option list without reconciling the selection against it
      // (setOptions filters selected against the new options, which would drop
      // chips whose value list hasn't arrived yet). Used by lazy value loading.
      //
      // `sel` forces the selection instead of leaving it alone — for a caller
      // that OWNS the value and is only borrowing the widget to display it,
      // e.g. a column picker showing the column a board restored while the
      // frame that has it is still loading (Blockr.reconcileColumn). Nothing
      // else may set a selection the option list does not contain: use
      // setOptions() and let it reconcile.
      /**
       * @param {BlockrSelectOption[] | BlockrSelectOption | null | undefined} opts
       * @param {string | string[] | null} [sel]
       */
      updateOptions(opts, sel) {
        options = Array.isArray(opts) ? opts : (opts != null ? [opts] : []);
        scanShape();
        if (sel != null) {
          selected = mode === 'multi'
            ? (Array.isArray(sel) ? sel.slice() : [sel])
            : sel;
        }
        render();
        if (isOpen) computePosition();
      },

      /** @param {boolean} flag */
      setLoading(flag) {
        loading = !!flag;
        if (isOpen) renderDropdown();
      },

      // Enter/leave server-search mode from a column-values response.
      // `truncated` means the full value list exceeds the server's limit
      // (sticky across queries); `total` is the full distinct count.
      /** @param {{ total?: number, truncated?: boolean } | null | undefined} info */
      setSearchInfo(info) {
        serverTruncated = !!(info && info.truncated);
        serverTotal = (info && info.total) || 0;
        if (isOpen) renderDropdown();
      },

      destroy() {
        if (destroyed) return;
        destroyed = true;
        if (searchTimer) clearTimeout(searchTimer);
        if (resizeObs) resizeObs.disconnect();
        close();

        if (dropdown.parentElement === document.body) {
          dropdown.remove();
        }

        control.removeEventListener('click', onControlClick);
        dropdown.removeEventListener('click', onDropdownClick);
        searchInput.removeEventListener('input', onSearchInput);
        searchInput.removeEventListener('keydown', onSearchKeydown);
        document.removeEventListener('click', onDocumentClick, true);
        root.removeEventListener('keydown', onRootKeydown);

        if (mode === 'multi') {
          control.removeEventListener('click', onTagRemoveClick);
          if (singleLine) control.removeEventListener('click', onMoreClick, true);
          if (reorderable && tagsEl) {
            tagsEl.removeEventListener('dragstart', onDragStart);
            tagsEl.removeEventListener('dragover', onDragOver);
            tagsEl.removeEventListener('dragend', onDragEnd);
            tagsEl.removeEventListener('drop', onDrop);
          }
        }

        Blockr.removeNode(root);
      }
    };
  };

  /** The dropdown on its own, hung off something the caller owns.
   *
   * For a word in a block's sentence that IS one of its settings: clicking it
   * has to give the list, not a popover holding a control that gives the list.
   * Everything below the surface is the single select -- same options, same
   * tick on the current one, same filter box past the same threshold, same
   * arrows / type-ahead / Enter / Escape, same portal and same flip near the
   * bottom of the window -- because a menu that drifts from the select is a
   * second idiom to maintain. See blockr.docs design-system/pinned-controls.md.
   *
   * Opens immediately and destroys itself when it closes, so the caller keeps
   * a handle only to close it early (a re-render under it, say).
   *
   * @param {HTMLElement} anchor The element to hang under, usually a word.
   * @param {any} config `title`, `labelFirst`, plus the usual select options.
   */
  const createMenu = (anchor, config) => {
    const host = document.createElement('div');
    host.className = 'blockr-select-menu-host';
    document.body.appendChild(host);
    /** @type {ReturnType<typeof createSelect> | null} */
    let handle = null;
    let done = false;
    const teardown = () => {
      if (done) return;
      done = true;
      // After the click that closed it has finished: `close()` runs before
      // the option's own onChange, and destroying here synchronously would
      // pull the DOM out from under it.
      setTimeout(() => {
        if (handle) handle.destroy();
        Blockr.removeNode(host);
        if (config.onClose) config.onClose();
      }, 0);
    };
    handle = createSelect(host, Object.assign({}, config, {
      headless: true,
      anchor: anchor,
      allowEmpty: true,
      onClose: teardown
    }), 'single');
    handle.open();
    return { close: teardown, handle: handle };
  };

  Blockr.SelectCatalog = {
    single: (container, config) => /** @type {BlockrSelectSingleHandle} */ (createSelect(container, config, 'single')),
    multi: (container, config) => /** @type {BlockrSelectMultiHandle} */ (createSelect(container, config, 'multi')),
    menu: createMenu,
    // Exposed for tests: the arithmetic, without a layout engine.
    fitCount: fitCount,
    midTruncate: midTruncate
  };
})();
