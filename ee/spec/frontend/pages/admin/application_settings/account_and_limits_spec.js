import htmlApplicationSettingsAccountsAndLimit from 'test_fixtures/application_settings/accounts_and_limit.html';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { initMaxAccessTokenLifetime } from 'ee/pages/admin/application_settings/account_and_limits';

describe('AccountAndLimits', () => {
  beforeEach(() => {
    setHTMLFixture(htmlApplicationSettingsAccountsAndLimit);
    initMaxAccessTokenLifetime();
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('Maximum allowable lifetime for access token input logic', () => {
    /** @type {HTMLInputElement} */
    let checkbox;
    /** @type {HTMLInputElement} */
    let serviceAccountCheckbox;
    /** @type {HTMLInputElement} */
    let input;

    const updateCheckbox = (checked) => {
      checkbox.checked = checked;
      checkbox.dispatchEvent(new Event('change'));
    };

    beforeEach(() => {
      checkbox = document.getElementById(
        'application_setting_require_personal_access_token_expiry',
      );
      serviceAccountCheckbox = document.getElementById(
        'application_setting_service_access_tokens_expiration_enforced',
      );
      input = document.querySelector('.js-max-access-token-lifetime');
    });

    it('initial state', () => {
      expect(checkbox.checked).toBe(true);
      expect(input.readOnly).toBe(false);
    });

    it('toggles the readonly state based on checkbox changes', () => {
      input.value = '30';
      if (serviceAccountCheckbox) {
        serviceAccountCheckbox.checked = false;
        serviceAccountCheckbox.dispatchEvent(new Event('change'));
      }
      updateCheckbox(false);

      expect(input.readOnly).toBe(true);
      expect(input.value).toBe('');
    });
  });
});
