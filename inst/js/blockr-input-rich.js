// Reusable rich-autocomplete input — extract to blockr.core when needed
//
// Similar to Blockr.Input but with two-line dropdown items showing descriptions.
// Designed for argument name selection where users need to see what each option does.
//
// API:
//   Blockr.InputRich.create(container, config) -> { el, getValue, setValue, setItems, focus, destroy }

(() => {
  'use strict';

  const createRichInput = (container, config) => {
    const id = Blockr.uid('bri');
    const popupId = `${id}-popup`;

    // Config
    let items = (config.items || []).slice();
    const placeholder = config.placeholder || '';
    const onChange = config.onChange || null;
    const onConfirm = config.onConfirm || null;
    const onSelect = config.onSelect || null;
    let destroyed = false;

    // Autocomplete state
    let filtered = [];
    let highlightIdx = -1;
    let popupOpen = false;

    // DOM
    const root = document.createElement('div');
    root.className = 'blockr-input-rich';

    const field = document.createElement('input');
    field.type = 'text';
    field.className = 'blockr-input-rich__field';
    field.placeholder = placeholder;
    field.setAttribute('autocomplete', 'off');
    field.setAttribute('autocorrect', 'off');
    field.setAttribute('autocapitalize', 'off');
    field.setAttribute('spellcheck', 'false');
    if (config.value) field.value = config.value;

    const popup = document.createElement('div');
    popup.className = 'blockr-input-rich__popup';
    popup.id = popupId;
    popup.setAttribute('role', 'listbox');

    root.appendChild(field);
    root.appendChild(popup);
    container.appendChild(root);

    // --- Filtering ---

    const filterItems = (query) => {
      if (!query) { filtered = items.slice(); return; }
      const q = query.toLowerCase();
      filtered = [];
      for (const item of items) {
        const t = item.text.toLowerCase();
        // Match anywhere in text, not just prefix — helps find "x11.seasonalma" by typing "seasonal"
        if (t.indexOf(q) >= 0) filtered.push(item);
      }
      // Sort: prefix matches first, then contains
      filtered.sort((a, b) => {
        const aPrefix = a.text.toLowerCase().indexOf(q) === 0 ? 0 : 1;
        const bPrefix = b.text.toLowerCase().indexOf(q) === 0 ? 0 : 1;
        if (aPrefix !== bPrefix) return aPrefix - bPrefix;
        return a.text.localeCompare(b.text);
      });
    };

    const scrollHighlightIntoView = () => {
      popup.querySelector('.blockr-input-rich__item--highlighted')
        ?.scrollIntoView({ block: 'nearest' });
    };

    // --- Popup rendering ---

    const renderPopup = () => {
      popup.innerHTML = '';
      if (filtered.length === 0) { closePopup(); return; }

      if (highlightIdx >= filtered.length) highlightIdx = filtered.length - 1;
      if (highlightIdx < 0) highlightIdx = 0;

      for (let i = 0; i < filtered.length; i++) {
        const c = filtered[i];
        const item = document.createElement('div');
        item.className = 'blockr-input-rich__item';
        if (i === highlightIdx) item.className += ' blockr-input-rich__item--highlighted';
        item.setAttribute('role', 'option');
        item.setAttribute('data-idx', i);

        // Line 1: name + meta tag
        const line1 = document.createElement('div');
        line1.className = 'blockr-input-rich__item-line1';

        const textSpan = document.createElement('span');
        textSpan.className = 'blockr-input-rich__item-text';
        textSpan.textContent = c.text;
        line1.appendChild(textSpan);

        if (c.meta) {
          const metaSpan = document.createElement('span');
          metaSpan.className = 'blockr-input-rich__item-meta';
          metaSpan.textContent = c.meta;
          line1.appendChild(metaSpan);
        }

        item.appendChild(line1);

        // Line 2: description
        if (c.description) {
          const descSpan = document.createElement('div');
          descSpan.className = 'blockr-input-rich__item-desc';
          descSpan.textContent = c.description;
          item.appendChild(descSpan);
        }

        popup.appendChild(item);
      }

      if (!popupOpen) openPopup();
      scrollHighlightIntoView();
    };

    // --- Popup open / close ---

    const openPopup = () => {
      if (popupOpen || destroyed) return;
      popupOpen = true;
      root.classList.add('blockr-input-rich--popup-open');
    };

    const closePopup = () => {
      if (!popupOpen) return;
      popupOpen = false;
      root.classList.remove('blockr-input-rich--popup-open');
      popup.innerHTML = '';
      highlightIdx = 0;
    };

    // --- Completion acceptance ---

    const acceptCompletion = (idx) => {
      if (idx < 0 || idx >= filtered.length) return;
      const c = filtered[idx];
      field.value = c.insertText || c.text;
      closePopup();
      if (onSelect) onSelect(c);
      if (onChange) onChange();
    };

    // --- Event handlers ---

    const onFieldInput = () => {
      const query = field.value.trim();
      filterItems(query);
      highlightIdx = 0;

      if (filtered.length > 0) {
        renderPopup();
      } else {
        closePopup();
      }

      if (onChange) onChange();
    };

    const onFieldFocus = () => {
      // Show all items on focus if field is empty
      if (!field.value.trim()) {
        filterItems('');
        highlightIdx = 0;
        if (filtered.length > 0) renderPopup();
      }
    };

    const onFieldKeydown = (e) => {
      if (popupOpen) {
        switch (e.key) {
          case 'ArrowDown':
            e.preventDefault();
            highlightIdx = (highlightIdx + 1) % filtered.length;
            renderPopup();
            break;
          case 'ArrowUp':
            e.preventDefault();
            highlightIdx = (highlightIdx - 1 + filtered.length) % filtered.length;
            renderPopup();
            break;
          case 'Enter':
            e.preventDefault();
            acceptCompletion(highlightIdx);
            break;
          case 'Tab':
            e.preventDefault();
            acceptCompletion(highlightIdx);
            break;
          case 'Escape':
            e.preventDefault();
            closePopup();
            break;
        }
      } else {
        if (e.key === 'Enter') {
          e.preventDefault();
          if (onConfirm) onConfirm(field.value.trim());
        }
      }
    };

    const onPopupClick = (e) => {
      const item = e.target.closest('.blockr-input-rich__item');
      if (item) {
        const idx = parseInt(item.getAttribute('data-idx'), 10);
        if (!isNaN(idx)) {
          acceptCompletion(idx);
          field.focus();
        }
      }
    };

    const onDocumentClick = (e) => {
      if (!root.contains(e.target)) closePopup();
    };

    const onFieldBlur = () => {
      setTimeout(() => {
        if (!root.contains(document.activeElement)) closePopup();
      }, 150);
    };

    // --- Bind events ---

    field.addEventListener('input', onFieldInput);
    field.addEventListener('focus', onFieldFocus);
    field.addEventListener('keydown', onFieldKeydown);
    field.addEventListener('blur', onFieldBlur);
    popup.addEventListener('mousedown', (e) => e.preventDefault());
    popup.addEventListener('click', onPopupClick);
    document.addEventListener('click', onDocumentClick, true);

    // --- Public API ---

    return {
      el: root,

      getValue() { return field.value.trim(); },

      setValue(v) { field.value = v || ''; },

      setItems(newItems) {
        items = (newItems || []).slice();
      },

      focus() { field.focus(); },

      destroy() {
        if (destroyed) return;
        destroyed = true;
        closePopup();
        field.removeEventListener('input', onFieldInput);
        field.removeEventListener('focus', onFieldFocus);
        field.removeEventListener('keydown', onFieldKeydown);
        field.removeEventListener('blur', onFieldBlur);
        popup.removeEventListener('click', onPopupClick);
        document.removeEventListener('click', onDocumentClick, true);
        Blockr.removeNode(root);
      }
    };
  };

  Blockr.InputRich = {
    create: (container, config) => createRichInput(container, config)
  };
})();
