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

    const entryOf = (name) => catalog[name] || { type: 'unknown', arg: name };
    const rowIndex = (name) => args.findIndex((a) => a.name === name);
    const send = () => { if (config.onChange) config.onChange(args); };

    /* REMOVAL IS EXPLICIT, and an empty value is not removal: an argument
       just added has no value yet, and a multi you cleared is one you are
       about to fill. The expression builder skips empty rows. */
    const setValue = (name, value) => {
      const i = rowIndex(name);
      if (i >= 0) args[i].value = value;
      send();
      render();
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

    /* ---- the picker ------------------------------------------------------ */
    const picker = () => {
      const wrap = el('div', 'seas-add');
      const taken = args.map((a) => a.name);
      const options = Object.keys(catalog)
        // A hidden argument is still in the catalog -- a restored board that
        // holds one renders its control and its description -- it is only
        // not offered. See data-raw/x13-args.R for the three rules.
        .filter((k) => taken.indexOf(k) < 0 && !catalog[k].hidden)
        .map((k) => ({
          value: k,
          // A spec has no `arg` of its own: an empty label leaves the row
          // showing the name once rather than twice.
          label: catalog[k].arg || '',
          group: catalog[k].spec || '',
          description: catalog[k].description || ''
        }));
      Blockr.SelectCatalog.single(wrap, {
        options: options, allowEmpty: true, selected: '',
        placeholder: 'Add an argument',
        searchPlaceholder: 'Search ' + options.length +
          ' arguments by name or by what the manual says',
        onChange: (v) => { if (v) addRow(v); }
      });
      wrap.firstChild.classList.add('blockr-select--bordered');
      return wrap;
    };

    /* ---- render ---------------------------------------------------------- */
    const render = () => {
      container.textContent = '';
      args.forEach((row) => container.appendChild(argRow(row)));
      if (!args.length) {
        container.appendChild(el('div', 'seas-empty',
          'No arguments. X-13 decides everything, which is the usual answer.'));
      }
      container.appendChild(sentence());
      container.appendChild(picker());
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
