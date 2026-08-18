import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  initSetUserCapRadio,
  initGroupSecretsManagerSettings,
} from 'ee/groups/settings/permissions/index';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';

Vue.use(VueApollo);

describe('Group Settings Permissions', () => {
  describe('initGroupSecretsManagerSettings', () => {
    afterEach(() => {
      resetHTMLFixture();
    });

    it('does not initialize when mount element is not in the DOM', () => {
      setHTMLFixture('<div></div>');

      expect(initGroupSecretsManagerSettings()).toBe(null);
    });

    it('mounts the SecretsManagerSettings component', () => {
      setHTMLFixture(`
        <div class="js-group-secrets-manager-settings"
             data-can-manage-secrets-manager="true"
             data-full-path="gitlab-org/gitlab"
             data-group-id="123"
             data-top-level-group-full-path="gitlab-org">
        </div>
      `);

      const result = initGroupSecretsManagerSettings();

      expect(result).not.toBe(null);
      expect(result.$el).toBeDefined();
    });
  });
});

describe('RadioNumberCombo', () => {
  const setDOM = ({ seatControl = 'off', userCap = '' } = {}) => {
    const userCapChecked = seatControl === 'userCap' ? 'checked="checked"' : '';
    const offChecked = seatControl === 'off' ? 'checked="checked"' : '';

    const fixtureTemplate = `
      <div id="js-seat-control">
        <div>
          <input type="radio" value="user_cap" ${userCapChecked} name="group[seat_control]" id="group_seat_control_user_cap">
          <input type="number" value="${userCap}" name="group[new_user_signups_cap]" id="group_new_user_signups_cap">
          <p class="gl-field-error hidden">This field is required.</p>
        </div>
        <input type="radio" value="off" ${offChecked} name="group[seat_control]" id="group_seat_control_off">
      </div>`;

    setHTMLFixture(fixtureTemplate);
  };

  const userCapInputValue = (value) => {
    const input = document.querySelector('#group_new_user_signups_cap');

    if (value) {
      input.value = value;
    }

    return input.value;
  };

  const clickOffRadio = () => {
    document.querySelector('#group_seat_control_off').click();
  };

  const clickUserCapRadio = () => {
    document.querySelector('#group_seat_control_user_cap').click();
  };

  afterEach(() => {
    resetHTMLFixture();
  });

  it('shows the input value if initialized with a user cap', () => {
    setDOM({ seatControl: 'userCap', userCap: 5 });

    initSetUserCapRadio();

    expect(userCapInputValue()).toEqual('5');
  });

  it('hides the input value initialized off', () => {
    setDOM({ seatControl: 'off' });

    initSetUserCapRadio();

    expect(userCapInputValue()).toEqual('');
  });

  it('hides the input value if off is selected', () => {
    setDOM({ seatControl: 'userCap', userCap: 10 });

    initSetUserCapRadio();

    clickOffRadio();

    expect(userCapInputValue()).toEqual('');
  });

  it('restores the input value if user cap is selected again', () => {
    setDOM({ seatControl: 'userCap', userCap: 20 });

    initSetUserCapRadio();

    clickOffRadio();

    clickUserCapRadio();

    expect(userCapInputValue()).toEqual('20');
  });

  it('restores the updated input value if the user changes it', () => {
    setDOM({ seatControl: 'userCap', userCap: 20 });

    initSetUserCapRadio();

    userCapInputValue('300');

    clickOffRadio();

    clickUserCapRadio();

    expect(userCapInputValue()).toEqual('300');
  });
});
