import { GlDatepicker } from '@gitlab/ui';
import { createTestingPinia } from '@pinia/testing';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import MaxExpirationDateMessage from 'ee/vue_shared/components/access_tokens/max_expiration_date_message.vue';
import AccessTokenForm from '~/vue_shared/access_tokens/components/access_token_form.vue';
import { useAccessTokens } from '~/vue_shared/access_tokens/stores/access_tokens';
import { mountExtended } from 'helpers/vue_test_utils_helper';

Vue.use(PiniaVuePlugin);

describe('AccessTokenForm', () => {
  let wrapper;

  const pinia = createTestingPinia();
  useAccessTokens();

  const accessTokenMaxDate = '2021-07-06';
  const accessTokenMinDate = '2020-07-06';
  const accessTokenAvailableScopes = [];
  const accessTokenTableUrl = '/-/personal_access_tokens';

  const createComponent = (provide = {}) => {
    wrapper = mountExtended(AccessTokenForm, {
      pinia,
      provide: {
        accessTokenMaxDate,
        accessTokenMinDate,
        accessTokenAvailableScopes,
        accessTokenTableUrl,
        ...provide,
      },
    });
  };

  const findDatepicker = () => wrapper.findComponent(GlDatepicker);
  const findMaxExpirationDateMessage = () => wrapper.findComponent(MaxExpirationDateMessage);

  describe('expiration field', () => {
    it('contains a datepicker with correct props', () => {
      createComponent();

      const datepicker = findDatepicker();
      expect(datepicker.exists()).toBe(true);
      expect(datepicker.props()).toMatchObject({
        minDate: new Date(accessTokenMinDate),
        maxDate: new Date(accessTokenMaxDate),
      });
    });

    it('shows a description', () => {
      createComponent();

      expect(findMaxExpirationDateMessage().props('maxDate').getTime()).toBe(
        new Date(accessTokenMaxDate).getTime(),
      );
    });
  });
});
