/* The seas block's control surface: an argument list, and a sentence.
 *
 * ONE STATE, THE ROWS. Everything on screen is a view of the same list of
 * `{name, value}` arguments. There is no second vocabulary, no common layer
 * and no owned rows: a suggestion writes a row, the picker adds a row, and
 * the row is what the block exports.
 *
 * A SPEC IS AN ARGUMENT. `seas(x, x11 = "")` is how the package switches the
 * decomposition, and the empty string is a legal value rather than a special
 * case, so `x11` is an entry in the catalog with a text control. The one
 * asymmetry that follows: a spec row is in the call while empty, and every
 * other row is skipped until it has a value, because a row with no value yet
 * is a row being filled in. That comes from what X-13 accepts.
 */
(() => {
  'use strict';

  const ns = window.SeasArgs = window.SeasArgs || {};

  /** Arguments whose value list is known but does not close: X-13 takes dated
   *  terms here (ao1951.may, rp1988.jan-1988.dec) that no catalog can hold. */
  const OPEN_RE = /^(ao|ls|tc|so|rp|tl)\d{4}\.[a-z]{3}/i;

  /** How many suggestions the sentence carries. */
  const SHOWN = 5;

  /** blockr.dplyr's plus, so the add bar here is the one the arrange and
   *  rename blocks already use. */
  const PLUS = '<svg xmlns="http://www.w3.org/2000/svg" width="14" ' +
    'height="14" fill="currentColor" viewBox="0 0 16 16"><path d="M8 2a.5.5 ' +
    '0 0 1 .5.5v5h5a.5.5 0 0 1 0 1h-5v5a.5.5 0 0 1-1 0v-5h-5a.5.5 0 0 1 ' +
    '0-1h5v-5A.5.5 0 0 1 8 2"/></svg>';

  const el = (tag, cls, txt) => {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (txt != null) n.textContent = txt;
    return n;
  };

  const isMulti = (entry) => entry && entry.type === 'multi-enum';
  const isSpec = (entry) => entry && entry.type === 'spec';
  const hasValues = (entry) => !!(entry && entry.values && entry.values.length);

  ns.mount = (container, config) => {
    const catalog = config.catalog || {};
    const suggestions = config.suggestions || [];
    const openArgs = config.open || [];
    let args = (config.args || []).slice();
    /** Is the picker showing in place of the add bar? View state, not saved:
     *  a restored block starts on the bar. */
    let adding = false;

    const entryOf = (name) => catalog[name] || { type: 'unknown', arg: name };
    const rowIndex = (name) => args.findIndex((a) => a.name === name);
    const send = () => { if (config.onChange) config.onChange(args); };

    /* REMOVAL IS EXPLICIT, and an empty value is not removal: an argument
       just added has no value yet, and a multi you cleared is one you are
       about to fill. The expression builder skips empty rows. */
    /* A VALUE CHANGE DOES NOT REDRAW THE BLOCK. The control that produced it
       is already showing the new state, and rebuilding the container throws
       away the element the user is typing in: a multi select loses focus
       after the first Backspace, so the second one goes nowhere. Only rows
       appearing or disappearing change the shape of this thing. */
    const setValue = (name, value) => {
      const i = rowIndex(name);
      if (i >= 0) args[i].value = value;
      send();
    };
    const addRow = (name, value) => {
      if (rowIndex(name) >= 0) return;
      const v = value === undefined
        ? (isMulti(entryOf(name)) ? [] : '')
        : value;
      args.push({ name: name, value: v });
      send();
      render();
    };
    const dropRow = (name) => {
      const i = rowIndex(name);
      if (i >= 0) args.splice(i, 1);
      send();
      render();
    };

    /* ---- the value side ------------------------------------------------ */
    const valueControl = (host, row) => {
      const entry = entryOf(row.name);

      if (hasValues(entry) && !isSpec(entry)) {
        const options = entry.values.map((v) => ({
          value: v.value, label: v.description || ''
        }));
        const cfg = { options: options, onChange: (v) => setValue(row.name, v) };
        if (isMulti(entry)) {
          cfg.selected = Array.isArray(row.value) ? row.value.slice() : [];
          // A typed value is not in the catalog, so it has to be carried as
          // an option or the component cannot render its tag.
          cfg.selected.forEach((v) => {
            if (!options.some((o) => o.value === v)) {
              options.push({ value: v, label: 'typed' });
            }
          });
          cfg.placeholder = 'Nothing set';
          if (openArgs.indexOf(row.name) >= 0) {
            cfg.allowCreate = (q) => (OPEN_RE.test(q.trim())
              ? q.trim().toLowerCase() : null);
          }
          Blockr.SelectCatalog.multi(host, cfg);
        } else {
          cfg.selected = row.value == null ? '' : String(row.value);
          cfg.allowEmpty = true;
          cfg.placeholder = entry.default != null
            ? 'Nothing set, X-13 uses ' + entry.default
            : 'Nothing set, X-13 decides';
          Blockr.SelectCatalog.single(host, cfg);
        }
        host.firstChild.classList.add('blockr-select--bordered');
        return;
      }

      const inp = el('input', 'seas-text');
      inp.type = 'text';
      inp.value = row.value == null ? '' : row.value;
      inp.placeholder = isSpec(entry)
        ? 'empty: naming the spec is what switches it on'
        : (entry.type === 'numeric' ? 'a number' : 'free text');
      inp.addEventListener('change', () => setValue(row.name, inp.value));
      host.appendChild(inp);
    };

    /* ---- a row, full width --------------------------------------------- */
    const argRow = (row) => {
      const entry = entryOf(row.name);
      const box = el('div', 'seas-row');

      const head = el('div', 'seas-row__head');
      head.appendChild(el('code', null, row.name));
      const line = el('span', null, (entry.description || '').split('. ')[0]);
      line.title = entry.description || '';
      head.appendChild(line);
      const rm = el('button', 'seas-row__rm', '×');
      rm.type = 'button';
      rm.title = 'Remove';
      rm.addEventListener('click', () => dropRow(row.name));
      head.appendChild(rm);
      box.appendChild(head);

      const ctl = el('div', 'seas-row__ctl');
      valueControl(ctl, row);
      box.appendChild(ctl);
      return box;
    };

    /* ---- the sentence --------------------------------------------------- */
    const sentence = () => {
      const line = el('div', 'seas-try');
      const taken = args.map((a) => a.name);
      const seen = {};
      const todo = suggestions.filter((s) => {
        if (taken.indexOf(s.name) >= 0) return false;
        // Several labels write one argument; the sentence carries the first.
        if (seen[s.name]) return false;
        seen[s.name] = true;
        return true;
      });
      if (!todo.length) return line;

      const items = todo.slice(0, SHOWN);
      line.appendChild(el('span', null, 'Try '));
      items.forEach((s, i) => {
        if (i) {
          line.appendChild(el('span', null,
            i === items.length - 1 ? ' or ' : ', '));
        }
        if (s.before) line.appendChild(el('span', null, s.before));
        const b = el('button', 'seas-try__link', s.say);
        b.type = 'button';
        b.title = s.of + ' on seasonal.website. Sets ' + s.name + '.';
        b.addEventListener('click', () => addRow(s.name, s.value));
        line.appendChild(b);
        if (s.after) line.appendChild(el('span', null, s.after));
      });
      line.appendChild(el('span', null, '.'));
      return line;
    };

    /* ---- adding one ------------------------------------------------------ */
    /* AN ADD IS AN ACTION, NOT A FIELD. The picker is a bordered select the
       same height as every value control, so as the last thing in the block
       it read as one more argument whose placeholder happened to say "Add".
       It hides behind blockr.dplyr's add bar now -- a muted link with a plus,
       `.blockr-add-row` in blockr-blocks.css -- and opens in place, already
       open, so reaching the finder is one click rather than two. */
    const addBar = () => {
      const bar = el('div', 'seas-add');
      const link = el('button', 'seas-add__link');
      link.type = 'button';
      link.innerHTML = '<span class="seas-add__icon">' + PLUS +
        '</span> Add argument';
      link.addEventListener('click', () => {
        adding = true;
        render();
      });
      bar.appendChild(link);
      return bar;
    };

    /* THE LINE, NOT A MENU. You type an argument the way you would type it
       in R: the completions are the catalogue while the caret is in the name,
       and that argument's own values once the name is settled by a space or
       an `=`.

       THE COMPLETION LIVES INSIDE THE INPUT, as selected text. It used to be
       a grey <div> under a transparent <input>, and the two could not be made
       to line up: a browser lays an input's text out in an internal box with
       its own centring and scroll origin, so identical fonts still drew the
       string twice, a sub-pixel apart. Selecting the completed tail has
       nothing to align -- typing replaces it, and accepting is collapsing the
       selection.

       ENTER IS THE KEY AND IT SAYS SO. blockr.docs/design-system's keystroke
       vocabulary is built on Enter -- verb plus muted glyph, a bare `↵` where
       it is tight -- and Tab appears nowhere in it. Tab still works for hands
       that reach for it; it is not advertised. */
    const consoleLine = () => {
      const wrap = el('div', 'seas-add seas-line');
      const box = el('div', 'seas-line__box');
      const input = document.createElement('input');
      input.className = 'seas-line__input';
      input.spellcheck = false;
      input.autocomplete = 'off';
      input.placeholder = 'x11.seasonalma = s3x9';
      box.appendChild(input);
      const chip = el('div', 'seas-line__chip');
      box.appendChild(chip);
      wrap.appendChild(box);

      const hint = el('div', 'seas-line__hint');
      wrap.appendChild(hint);
      const list = el('div', 'seas-line__list');
      wrap.appendChild(list);
      /** WHAT FINISHES THE ARGUMENT IS NOT A VALUE, SO IT IS NOT IN THE LIST.
       *  It was, for a while, as a sentinel row, because Enter had to do two
       *  jobs: take the highlighted value and end the list. Shift+Enter takes
       *  the second job, so the list holds only things X-13 accepts and this
       *  footer says what ends it. */
      const foot = el('div', 'seas-line__foot');
      wrap.appendChild(foot);

      let idx = 0;
      /** Has the highlight been moved by hand -- an arrow or a click? Enter's
       *  guard against adding something you did not type towards applies only
       *  while it has not: once you have walked to a row, you have chosen it,
       *  and it does not have to be a completion of what you typed. */
      let moved = false;

      const taken = () => args.map((a) => a.name);
      const names = () => Object.keys(catalog).filter((k) =>
        !catalog[k].hidden && taken().indexOf(k) < 0);

      /* `name`, `name value`, `name = value`, `name = "value"`, and for a
         multi `name = a, b`. Whatever R would take, plus what a hurry types. */
      const parse = (line) => {
        const m = /^\s*([a-zA-Z0-9._]*)\s*(=)?\s*(.*)$/.exec(line);
        return {
          name: m[1] || '',
          settled: !!m[2] || /^\s*[a-zA-Z0-9._]+\s+/.test(line),
          value: (m[3] || '').replace(/^["']|["']$/g, '')
        };
      };

      const matchNames = (q) => {
        const all = names();
        if (!q) return all;
        const lower = q.toLowerCase();
        const starts = [], seg = [], sub = [], desc = [];
        all.forEach((k) => {
          const n = k.toLowerCase();
          const tail = n.slice(n.lastIndexOf('.') + 1);
          if (n.indexOf(lower) === 0) starts.push(k);
          else if (tail.indexOf(lower) === 0) seg.push(k);
          else if (n.indexOf(lower) > -1) sub.push(k);
          else if ((catalog[k].description || '').toLowerCase()
            .indexOf(lower) > -1) desc.push(k);
        });
        return starts.concat(seg, sub, desc);
      };

      const lastFragment = (value) => String(value).split(',').pop().trim();

      const matchValues = (name, q) => {
        const entry = entryOf(name);
        if (!hasValues(entry)) return [];
        const picked = isMulti(entry)
          ? String(q).split(',').slice(0, -1).map((x) => x.trim()) : [];
        const frag = isMulti(entry) ? lastFragment(q) : q;
        const vals = entry.values.map((v) => v.value)
          .filter((v) => picked.indexOf(v) < 0);
        if (!frag) return vals;
        const lower = frag.toLowerCase();
        return vals.filter((v) => v.toLowerCase().indexOf(lower) === 0)
          .concat(vals.filter((v) => v.toLowerCase().indexOf(lower) > 0));
      };

      /* WHAT WAS TYPED, NOT WHAT WAS COMPLETED. The completion lives in the
         input as selected text, so `input.value` already holds the candidate;
         matching against it finds only that candidate, and the list collapses
         to one row the moment the first completion lands. Everything that
         asks "what is the user looking for" asks this. */
      const typedText = () => {
        const end = input.value.length;
        if (input.selectionEnd === end && input.selectionStart < end) {
          return input.value.slice(0, input.selectionStart);
        }
        return input.value;
      };

      const stateOf = () => {
        const p = parse(typedText());
        const known = Object.prototype.hasOwnProperty.call(catalog, p.name);
        const entry = entryOf(p.name);
        const stage = (p.settled && known) ? 'value' : 'name';
        return {
          p: p, entry: entry, known: known, stage: stage,
          multi: stage === 'value' && isMulti(entry),
          frag: stage === 'value'
            ? (isMulti(entry) ? lastFragment(p.value) : p.value) : p.name,
          opts: stage === 'value' ? matchValues(p.name, p.value)
            : matchNames(p.name)
        };
      };

      /* What Enter does right now, in one word, for the chip and the hint. */
      const enterMeans = (st) => {
        if (st.stage === 'name') {
          if (st.known) return 'add';
          return st.opts.length && st.frag &&
            st.opts[idx].toLowerCase().indexOf(st.frag.toLowerCase()) === 0
            ? 'pick' : '';
        }
        const pick = st.opts[idx];
        if (st.multi) return pick ? 'add value' : 'done';
        return hasValues(st.entry) && !pick ? '' : 'add';
      };

      /* What Shift+Enter would add right now, for the footer. */
      const commitNote = (st) => {
        if (!st.known) return '';
        if (st.multi) {
          const picked = st.p.value.split(',').map((x) => x.trim())
            .filter((x) => x.length);
          return picked.length
            ? 'add ' + st.p.name + ' with ' + picked.join(', ')
            : 'add ' + st.p.name + ' with nothing set';
        }
        const v = st.p.settled ? st.p.value.trim() : '';
        return v ? 'add ' + st.p.name + ' = ' + v : 'add ' + st.p.name;
      };

      const paint = () => {
        const st = stateOf();
        if (idx >= st.opts.length) idx = 0;

        list.innerHTML = '';
        // Enough rows that arrowing through a spec's arguments is possible;
        // the box scrolls and the active row is kept in view.
        st.opts.slice(0, 50).forEach((o, i) => {
          const row = el('div', 'seas-line__opt' + (i === idx ? ' is-on' : ''));
          row.dataset.i = String(i);
          row.appendChild(el('code', null, o));
          let note = '';
          if (st.stage === 'name') {
            note = (catalog[o].description || '').split('. ')[0];
          } else if (hasValues(st.entry)) {
            const hit = st.entry.values.filter((v) => v.value === o)[0];
            note = hit ? (hit.description || '') : '';
          }
          row.appendChild(el('span', null, note));
          // The house's compact form: a bare glyph on the row Enter acts on.
          row.appendChild(el('span', 'seas-line__kbd', i === idx ? '↵' : ''));
          list.appendChild(row);
        });
        const active = list.querySelector('.is-on');
        if (active && active.scrollIntoView) {
          active.scrollIntoView({ block: 'nearest' });
        }

        const means = enterMeans(st);
        chip.textContent = means ? '↵' : '';
        chip.title = means ? 'Enter: ' + means : '';

        const note = commitNote(st);
        foot.textContent = '';
        if (note) {
          foot.appendChild(el('span', null, 'Done: ' + note));
          foot.appendChild(el('span', 'seas-line__kbd', '⇧↵'));
        }
        foot.className = 'seas-line__foot' +
          (note ? '' : ' is-off') + (st.opts.length ? '' : ' is-solo');
        list.className = 'seas-line__list' + (note ? ' has-foot' : '');

        if (st.stage === 'value') {
          hint.textContent = st.multi
            ? 'Enter ↵ adds this value, Shift ⇧↵ finishes the list'
            : (hasValues(st.entry)
               ? 'Enter ↵ takes the value and adds the argument'
               : 'Free text. Enter ↵ adds the argument');
        } else if (st.known) {
          hint.textContent = 'Enter ↵ adds it, or type = for its values';
        } else {
          hint.textContent = st.opts.length
            ? 'Enter ↵ takes the highlighted one'
            : 'Nothing matches';
        }
      };

      const collapse = () => {
        const n = input.value.length;
        input.setSelectionRange(n, n);
      };

      /* The completion, inside the input and selected. */
      const autofill = () => {
        const st = stateOf();
        const pick = st.opts[idx];
        const typed = typedText();
        if (!pick || !st.frag) {
          if (typed !== input.value) {
            input.value = typed;
            collapse();
          }
          return;
        }
        if (pick.toLowerCase().indexOf(st.frag.toLowerCase()) !== 0) {
          // The highlighted option is not a completion of what was typed --
          // a description match, say -- so there is nothing to show inline.
          if (typed !== input.value) {
            input.value = typed;
            collapse();
          }
          return;
        }
        const rest = pick.slice(st.frag.length);
        input.value = typed + rest;
        input.setSelectionRange(typed.length, input.value.length);
      };

      /* Enter, and Tab for hands that reach for it. */
      const accept = () => {
        const st = stateOf();
        collapse();
        const pick = st.opts[idx];
        if (!pick) return false;

        if (st.stage === 'value') {
          const parts = st.multi
            ? st.p.value.split(',').map((x) => x.trim()) : [st.p.value];
          parts[parts.length - 1] = pick;
          input.value = st.p.name + ' = ' + parts.join(', ');
          collapse();
          idx = 0;
          moved = false;
          paint();
          return true;
        }

        const entry = entryOf(pick);
        const wantsValue = hasValues(entry) ||
          entry.type === 'numeric' || entry.type === 'text';
        input.value = pick + (wantsValue ? ' = ' : '');
        collapse();
        idx = 0;
        moved = false;
        paint();
        return true;
      };

      const commit = () => {
        const st = stateOf();
        if (!st.known) return;
        const entry = st.entry;
        let value = st.p.settled ? st.p.value : '';
        if (isMulti(entry)) {
          value = value ? value.split(',').map((x) => x.trim())
            .filter((x) => x.length) : [];
        }
        input.value = '';
        idx = 0;
        moved = false;
        addRow(st.p.name, value);
      };

      /* TWO KEYS, ONE MEANING EACH. Enter takes what is highlighted. Shift
         +Enter adds the argument with whatever is in the line, whatever is
         highlighted. For a single value Enter alone is the whole gesture,
         because taking the value is also the end of it; for a list it is one
         Enter per value and one Shift+Enter to stop. */
      const onEnter = (shift) => {
        const st = stateOf();

        if (shift) {
          if (st.known) commit();
          return;
        }

        if (st.stage === 'name') {
          if (st.known && !st.frag) { commit(); return; }
          if (st.known && st.opts.indexOf(st.p.name) < 0) { commit(); return; }
          const pick = st.opts[idx];
          // Never add something you did not type towards, UNLESS you walked
          // to it: a description match is not a prefix, so blind Enter skips
          // it, and an arrow key makes it yours.
          if (!pick ||
              (!moved && (!st.frag ||
                pick.toLowerCase().indexOf(st.frag.toLowerCase()) !== 0))) {
            if (st.known) commit();
            return;
          }
          accept();
          // A name with no value to give is a whole argument on its own.
          const entry = entryOf(pick);
          if (!hasValues(entry) && entry.type !== 'numeric' &&
              entry.type !== 'text') {
            commit();
          }
          return;
        }

        /* ENTER TAKES WHAT IS HIGHLIGHTED, always. It used to ask whether
           anything had been typed or walked to, and answered "no" for the row
           the list had highlighted by default -- so Enter finished the list
           and threw that row away, while the row wore a ↵ saying otherwise.
           With nothing left to take, Enter finishes too, so a run of them
           never dead-ends. */
        const pick = st.opts[idx];

        if (st.multi) {
          if (!pick) { commit(); return; }
          if (accept()) {
            input.value = input.value + ', ';
            collapse();
            idx = 0;
            moved = false;
            paint();
          }
          return;
        }

        if (hasValues(st.entry) && pick) accept();
        commit();
      };

      input.addEventListener('input', (ev) => {
        idx = 0;
        moved = false;
        paint();
        const deleting = ev && ev.inputType &&
          ev.inputType.indexOf('delete') === 0;
        if (!deleting) autofill();
      });

      input.addEventListener('keydown', (ev) => {
        const st = stateOf();
        if (ev.key === 'Enter') { ev.preventDefault(); onEnter(ev.shiftKey); }
        else if (ev.key === 'Tab') { ev.preventDefault(); accept(); }
        else if (ev.key === 'ArrowDown') {
          /* ARROWS MOVE THE HIGHLIGHT AND NOTHING ELSE. They used to autofill
             the input with the highlighted option, which narrowed the list to
             that one option -- so the next press had nowhere to go, the list
             collapsed from eight rows to one, and the highlight looked stuck.
             Completion is what typing does; choosing is what arrows do. */
          ev.preventDefault();
          idx = Math.min(idx + 1, st.opts.length - 1);
          moved = true;
          paint();
          autofill();
        } else if (ev.key === 'ArrowUp') {
          ev.preventDefault();
          idx = Math.max(idx - 1, 0);
          moved = true;
          paint();
          autofill();
        } else if (ev.key === 'Escape') {
          ev.preventDefault();
          adding = false;
          render();
        }
      });

      list.addEventListener('click', (ev) => {
        const row = ev.target.closest('.seas-line__opt');
        if (!row) return;
        idx = Number(row.dataset.i);
        moved = true;
        onEnter(false);
        input.focus();
      });

      foot.addEventListener('click', () => {
        if (stateOf().known) commit();
        input.focus();
      });

      window.setTimeout(() => { input.focus(); paint(); }, 0);
      return wrap;
    };

    /* ---- render ---------------------------------------------------------- */
    const render = () => {
      container.textContent = '';
      // NOTHING IS SAID ABOUT AN EMPTY BLOCK. A sentence explaining that no
      // arguments are set explains an absence that needs no explaining, and
      // it sat where the first argument goes, so the block read as
      // structurally different empty than it did after one click. The
      // suggestions below carry it.
      args.forEach((row) => container.appendChild(argRow(row)));
      container.appendChild(sentence());
      container.appendChild(adding ? consoleLine() : addBar());
    };

    render();

    return {
      update: (state) => {
        args = (state.args || []).slice();
        render();
      }
    };
  };

  /* ---- Shiny wiring ---------------------------------------------------- */
  const mounted = {};

  Shiny.addCustomMessageHandler('seas-args-init', (msg) => {
    const container = document.getElementById(msg.id);
    if (!container) return;
    mounted[msg.id] = ns.mount(container, {
      catalog: msg.catalog, suggestions: msg.suggestions, open: msg.open,
      args: msg.args,
      onChange: (args) => Shiny.setInputValue(msg.id, { args: args },
                                              { priority: 'event' })
    });
  });

  Shiny.addCustomMessageHandler('seas-args-update', (msg) => {
    const h = mounted[msg.id];
    if (h) h.update(msg);
  });
})();
