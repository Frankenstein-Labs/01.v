/**
 * Toggle the AI panel maximized state in the DOM
 * @param {boolean} isMaximized - Whether the panel is maximized
 */
export const toggleAiPanelMaximizedClass = (isMaximized) => {
  document
    .querySelector('.js-page-layout')
    ?.classList.toggle('ai-panel-maximized', isMaximized ?? false);
};

/**
 * Toggle the AI panel open state on the document root (`:root`)
 * so global background assets (e.g. bloom → grand-ambient) can respond.
 * @param {boolean} isOpen - Whether an AI panel/chat is open
 */
export const toggleAiPanelOpenClass = (isOpen) => {
  document.documentElement.classList.toggle('ai-panel-is-open', isOpen ?? false);
};
