/**
 * SeasBlock — JS-driven seas() argument builder.
 *
 * Each row: [argument name (rich select)] = [value (adaptive)] [x]
 * Footer: "+ Add argument"
 *
 * Depends on: blockr-core.js, blockr-select-rich.js, blockr-select.js
 */
(() => {
  'use strict';

  let catalog = {};

  const buildNameItems = () => {
    return Object.entries(catalog).map(([key, entry]) => ({
      value: key,
      label: key,
      meta: entry.spec,
      description: entry.description
    }));
  };

  class SeasBlock {
    constructor(el) {
      this.el = el;
      this.rows = [];
      this.nextId = 1;
      this._callback = null;
      this._submitted = false;
      this._debounceTimer = null;
      this._nameItems = [];
      this._buildDOM();
    }

    _autoSubmit() {
      clearTimeout(this._debounceTimer);
      this._debounceTimer = setTimeout(() => this._submit(), 300);
    }

    _submit() {
      this._submitted = true;
      if (this._callback) this._callback(true);
    }

    // --- DOM ---

    _buildDOM() {
      this.card = document.createElement('div');
      this.card.className = 'seas-card';
      this.el.appendChild(this.card);

      this.indicatorsEl = document.createElement('div');
      this.indicatorsEl.className = 'seas-indicators';
      this.card.appendChild(this.indicatorsEl);

      this.listEl = document.createElement('div');
      this.listEl.className = 'seas-rows';
      this.card.appendChild(this.listEl);

      const addRow = document.createElement('div');
      addRow.className = 'blockr-add-row';
      const addLink = document.createElement('span');
      addLink.className = 'blockr-add-link';
      addLink.innerHTML = `<span class="blockr-add-icon">${Blockr.icons.plus}</span> Add argument`;
      addLink.addEventListener('click', () => {
        this._addRow('', null);
      });
      addRow.appendChild(addLink);
      this.card.appendChild(addRow);
    }

    _addRow(name, value) {
      const id = this.nextId++;
      const self = this;

      const row = document.createElement('div');
      row.className = 'blockr-row';
      row.setAttribute('data-row-id', id);

      // Name select (rich select with descriptions)
      const nameWrap = document.createElement('div');
      nameWrap.className = 'seas-name-wrap';
      row.appendChild(nameWrap);

      const nameInput = Blockr.SelectRich.create(nameWrap, {
        items: this._nameItems,
        selected: name || null,
        placeholder: 'argument\u2026',
        onChange: (value, item) => {
          self._rebuildValueSide(rowData, value);
          self._autoSubmit();
        }
      });

      // Equals separator
      const eqSep = document.createElement('span');
      eqSep.className = 'seas-eq-sep';
      eqSep.textContent = '=';
      row.appendChild(eqSep);

      // Value container
      const valueWrap = document.createElement('div');
      valueWrap.className = 'seas-value-wrap blockr-row-content';
      row.appendChild(valueWrap);

      // Remove button
      const rmBtn = document.createElement('button');
      rmBtn.className = 'blockr-row-remove';
      rmBtn.type = 'button';
      rmBtn.innerHTML = Blockr.icons.x;
      rmBtn.addEventListener('click', () => {
        this._removeRow(id);
        this._autoSubmit();
      });
      row.appendChild(rmBtn);

      const rowData = {
        id,
        nameInput,
        valueWrap,
        valueComponent: null,
        valueType: null,
        rowEl: row
      };

      this.listEl.appendChild(row);
      this.rows.push(rowData);
      this._updateUI();

      // Build value side for pre-set arguments
      if (name && catalog[name]) {
        this._rebuildValueSide(rowData, name, value);
      } else if (name && value != null) {
        this._buildTextValue(rowData, value);
      }
    }

    // --- Value side builders ---

    _rebuildValueSide(rowData, argName, initialValue) {
      this._destroyValueComponent(rowData);
      rowData.valueWrap.innerHTML = '';

      // Restore eq/value visibility in case previous type was spec
      const eqSep = rowData.rowEl.querySelector('.seas-eq-sep');
      if (eqSep) eqSep.style.display = '';
      rowData.valueWrap.style.display = '';

      const entry = catalog[argName];
      if (!entry) {
        this._buildTextValue(rowData, initialValue || '');
        return;
      }

      switch (entry.type) {
        case 'spec':
          this._buildSpecValue(rowData, entry);
          break;
        case 'enum':
          this._buildEnumValue(rowData, entry, initialValue);
          break;
        case 'multi-enum':
          this._buildMultiEnumValue(rowData, entry, initialValue);
          break;
        case 'numeric':
          this._buildNumericValue(rowData, entry, initialValue);
          break;
        case 'text':
        default:
          this._buildTextValue(rowData, initialValue || '');
          break;
      }
    }

    _buildSpecValue(rowData, entry) {
      // Hide the "=" and value side — spec args have no user-configurable value
      const eqSep = rowData.rowEl.querySelector('.seas-eq-sep');
      if (eqSep) eqSep.style.display = 'none';
      rowData.valueWrap.style.display = 'none';
      rowData.valueComponent = { el: null, destroy: () => {} };
      rowData.valueType = 'spec';
    }

    _buildEnumValue(rowData, entry, initialValue) {
      const self = this;
      // Values can be objects {value, label, description} or plain strings
      const items = entry.values.map(v =>
        typeof v === 'object' ? v : { value: v, label: v }
      );
      const defaultVal = initialValue || entry.default
        || (items.length > 0 ? items[0].value : '');

      const sel = Blockr.SelectRich.create(rowData.valueWrap, {
        items,
        selected: defaultVal,
        placeholder: 'Select\u2026',
        onChange: () => {
          self._autoSubmit();
        }
      });
      rowData.valueComponent = sel;
      rowData.valueType = 'enum';
    }

    _buildMultiEnumValue(rowData, entry, initialValue) {
      const self = this;
      // Multi-enum: values can be objects or plain strings
      // Blockr.Select.multi only takes plain string options, so extract values
      // but store the items for potential future rich multi-select
      const options = entry.values.map(v =>
        typeof v === 'object' ? v.value : v
      );
      const sel = Blockr.Select.multi(rowData.valueWrap, {
        options,
        selected: Array.isArray(initialValue) ? initialValue : [],
        placeholder: 'Select\u2026',
        reorderable: true,
        onChange: () => self._autoSubmit()
      });
      rowData.valueComponent = sel;
      rowData.valueType = 'multi-enum';
    }

    _buildNumericValue(rowData, entry, initialValue) {
      const self = this;
      const input = document.createElement('input');
      input.type = 'number';
      input.className = 'blockr-num-input';
      input.step = 'any';
      if (entry.default != null) input.placeholder = String(entry.default);
      if (initialValue != null) input.value = initialValue;

      input.addEventListener('input', () => self._autoSubmit());

      rowData.valueWrap.appendChild(input);
      rowData.valueComponent = { el: input, focus: () => input.focus(), destroy: () => {} };
      rowData.valueType = 'numeric';
    }

    _buildTextValue(rowData, initialValue) {
      const self = this;
      const input = document.createElement('input');
      input.type = 'text';
      input.className = 'seas-text-input';
      input.placeholder = 'value\u2026';
      if (initialValue) input.value = initialValue;

      input.addEventListener('input', () => self._autoSubmit());

      rowData.valueWrap.appendChild(input);
      rowData.valueComponent = { el: input, focus: () => input.focus(), destroy: () => {} };
      rowData.valueType = 'text';
    }

    _destroyValueComponent(rowData) {
      if (rowData.valueComponent) {
        if (typeof rowData.valueComponent.destroy === 'function') {
          rowData.valueComponent.destroy();
        }
        rowData.valueComponent = null;
        rowData.valueType = null;
      }
    }

    // --- Row management ---

    _removeRow(id) {
      if (this.rows.length <= 0) return;
      const idx = this.rows.findIndex(r => r.id === id);
      if (idx < 0) return;

      const rowData = this.rows[idx];
      rowData.nameInput?.destroy();
      this._destroyValueComponent(rowData);
      rowData.rowEl?.parentNode?.removeChild(rowData.rowEl);
      this.rows.splice(idx, 1);
      this._updateUI();
    }

    _updateUI() {
      for (const r of this.rows) {
        const btn = r.rowEl?.querySelector('.blockr-row-remove');
        if (btn) btn.style.visibility = '';
      }
    }

    // --- State ---

    _getRowValue(rowData) {
      if (!rowData.valueComponent) return null;
      switch (rowData.valueType) {
        case 'spec':
          return 'list()';
        case 'enum':
        case 'multi-enum':
          return rowData.valueComponent.getValue();
        case 'numeric': {
          const v = rowData.valueComponent.el.value;
          return v === '' ? null : parseFloat(v);
        }
        case 'text':
          return rowData.valueComponent.el.value || '';
        default:
          return null;
      }
    }

    _compose() {
      const args = [];
      for (const r of this.rows) {
        const name = r.nameInput ? r.nameInput.getValue() : '';
        const value = this._getRowValue(r);
        if (name) {
          args.push({ name, value });
        }
      }
      return { args };
    }

    getValue() {
      return this._submitted ? this._compose() : null;
    }

    setState(state) {
      while (this.rows.length > 0) {
        const r = this.rows[0];
        r.nameInput?.destroy();
        this._destroyValueComponent(r);
        r.rowEl?.parentNode?.removeChild(r.rowEl);
        this.rows.splice(0, 1);
      }
      const args = (state && state.args) || [];
      for (const a of args) {
        this._addRow(a.name, a.value);
      }
    }

    setCatalog(cat) {
      catalog = cat || {};
      this._nameItems = buildNameItems();
      for (const r of this.rows) {
        if (r.nameInput) r.nameInput.setItems(this._nameItems);
      }
    }

    setConnections(info) {
      this.indicatorsEl.innerHTML = '';
      if (info.xreg) this._addIndicator('xreg', 'connected');
      if (info.xtrans) this._addIndicator('xtrans', 'connected');
    }

    _addIndicator(label, status) {
      const row = document.createElement('div');
      row.className = 'seas-indicator-row';
      const labelSpan = document.createElement('span');
      labelSpan.className = 'seas-indicator-label';
      labelSpan.textContent = label;
      row.appendChild(labelSpan);
      const statusSpan = document.createElement('span');
      statusSpan.className = 'seas-indicator-status';
      statusSpan.textContent = status;
      row.appendChild(statusSpan);
      this.indicatorsEl.appendChild(row);
    }
  }

  // --- Shiny Input Binding ---

  const binding = new Shiny.InputBinding();
  Object.assign(binding, {
    find: (scope) => $(scope).find('.seas-block-container'),
    getId: (el) => el.id || null,
    getValue: (el) => el._block ? el._block.getValue() : null,
    setValue: (el, value) => { if (el._block) el._block.setState(value); },
    subscribe: (el, callback) => {
      if (el._block) el._block._callback = () => callback(true);
    },
    unsubscribe: (el) => {
      if (el._block) el._block._callback = null;
    },
    initialize: (el) => {
      el._block = new SeasBlock(el);
      if (el._pendingCatalog) {
        el._block.setCatalog(el._pendingCatalog);
        delete el._pendingCatalog;
      }
      if (el._pendingState) {
        el._block.setState(el._pendingState);
        delete el._pendingState;
      }
      if (el._pendingConnections) {
        el._block.setConnections(el._pendingConnections);
        delete el._pendingConnections;
      }
    }
  });
  Shiny.inputBindings.register(binding, 'blockr.seas');

  // --- Message handlers ---

  Shiny.addCustomMessageHandler('seas-catalog', (msg) => {
    const el = document.getElementById(msg.id);
    if (el && el._block) el._block.setCatalog(msg.catalog);
    else if (el) el._pendingCatalog = msg.catalog;
  });

  Shiny.addCustomMessageHandler('seas-block-update', (msg) => {
    const el = document.getElementById(msg.id);
    if (el && el._block) el._block.setState(msg.state);
    else if (el) el._pendingState = msg.state;
  });

  Shiny.addCustomMessageHandler('seas-connections', (msg) => {
    const el = document.getElementById(msg.id);
    if (el && el._block) el._block.setConnections(msg);
    else if (el) el._pendingConnections = msg;
  });
})();
