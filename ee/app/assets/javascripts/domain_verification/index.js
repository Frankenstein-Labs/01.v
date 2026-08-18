export function initRemoveButtonBehavior() {
  const emptyState = document.querySelector('.js-domain-empty-state');

  function removeRowSuccessCallback() {
    this.closest('tr').classList.add('!gl-hidden');

    const labelsCount = document.querySelectorAll('.js-domain-row:not(.gl-hidden\\!)').length;

    if (labelsCount < 1 && emptyState) {
      emptyState.classList.remove('gl-hidden');
    }
  }

  document.querySelectorAll('.js-remove-domain').forEach((button) => {
    button.addEventListener('ajax:success', removeRowSuccessCallback);
  });
}
