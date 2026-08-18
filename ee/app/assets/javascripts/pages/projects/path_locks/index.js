import initDeprecatedRemoveRowBehavior from '~/behaviors/deprecated_remove_row_behavior';

initDeprecatedRemoveRowBehavior();

const locks = document.querySelector('.js-path-locks');

locks.addEventListener('ajax:success', () => {
  const allRowsHidden = [...locks.querySelectorAll('li')].every((x) => x.offsetParent === null);

  if (allRowsHidden) {
    locks.querySelector('.js-path-locks-empty-state.hidden')?.classList?.remove('hidden');
    locks.querySelector('.js-path-locks-list')?.classList?.add('hidden');
  }
});
