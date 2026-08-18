import { mergeUrlParams } from '~/lib/utils/url_utility';

/**
 * Change the onboarding_status_email_opt_in query param values for OAuth sign up form actions.
 * When the user toggles the form based checkbox, this will toggle all the corresponding
 * OAuth sign up buttons as well to have that value.
 */
export function initOnboardingEmailOptIn() {
  const visibleCheckbox = document.querySelector('input#new_user_onboarding_status_email_opt_in');
  const forms = document.querySelectorAll('form.js-omniauth-form');

  if (!visibleCheckbox) {
    return;
  }

  visibleCheckbox.addEventListener('change', ({ target }) => {
    forms.forEach((oauthForm) => {
      const href = oauthForm.getAttribute('action');
      const newHref = mergeUrlParams(
        { onboarding_status_email_opt_in: target.checked.toString() },
        href,
      );

      oauthForm.setAttribute('action', newHref);
    });
  });
}
