import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { initOnboardingEmailOptIn } from 'ee/registrations/onboarding_email_opt_in';

describe('initOnboardingEmailOptIn', () => {
  afterEach(() => {
    resetHTMLFixture();
  });

  it('does nothing when the visible checkbox is not rendered', () => {
    setHTMLFixture('<form class="js-omniauth-form" action="/users/auth/google_oauth2"></form>');

    expect(() => initOnboardingEmailOptIn()).not.toThrow();
  });

  it('updates omniauth form actions when the visible checkbox changes', () => {
    setHTMLFixture(`
      <input id="new_user_onboarding_status_email_opt_in" type="checkbox" />
      <form class="js-omniauth-form" action="/users/auth/google_oauth2"></form>
    `);

    const checkbox = document.querySelector('#new_user_onboarding_status_email_opt_in');
    const form = document.querySelector('.js-omniauth-form');

    initOnboardingEmailOptIn();

    checkbox.checked = true;
    checkbox.dispatchEvent(new Event('change'));

    expect(form.getAttribute('action')).toBe(
      '/users/auth/google_oauth2?onboarding_status_email_opt_in=true',
    );
  });
});
