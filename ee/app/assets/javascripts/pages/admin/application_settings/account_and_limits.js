export const initMaxAccessTokenLifetime = () => {
  const input = document.querySelector('.js-max-access-token-lifetime');
  if (!input) {
    return;
  }
  const checkboxes = document.querySelectorAll(
    '#application_setting_require_personal_access_token_expiry, #application_setting_service_access_tokens_expiration_enforced',
  );

  const toggleInput = () => {
    if (Array.from(checkboxes).some((checkbox) => checkbox.checked)) {
      input.readOnly = false;
    } else {
      input.readOnly = true;
      input.value = '';
    }
  };
  toggleInput();
  checkboxes.forEach((checkbox) => {
    checkbox.addEventListener('change', toggleInput);
  });
};
