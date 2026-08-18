export const initTitleRegexToggle = () => {
  const toggle = document.querySelector('.js-title-regex-toggle');
  const fields = document.querySelector('.js-title-regex-fields');

  if (!toggle || !fields) return;

  const updateState = () => {
    const isChecked = toggle.checked;
    toggle.setAttribute('aria-expanded', isChecked);
    fields.classList.toggle('gl-hidden', !isChecked);
    fields.querySelectorAll('input[type="text"].form-control').forEach((el) => {
      el.toggleAttribute('disabled', !isChecked);
    });
  };

  toggle.addEventListener('change', updateState);
  updateState();
};
