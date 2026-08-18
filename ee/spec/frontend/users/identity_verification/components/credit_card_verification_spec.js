import { GlSprintf, GlLink } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import axios from '~/lib/utils/axios_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import Zuora, { Event } from 'ee/billings/components/zuora_simple.vue';
import CreditCardVerification, {
  EVENT_CATEGORY,
  EVENT_SUCCESS,
  EVENT_FAILED,
} from 'ee/users/identity_verification/components/credit_card_verification.vue';
import Captcha from 'ee/users/identity_verification/components/identity_verification_captcha.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { createAlert } from '~/alert';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import {
  I18N_GENERIC_ERROR,
  RELATED_TO_BANNED_USER,
  CONTACT_SUPPORT_URL,
} from 'ee/users/identity_verification/constants';

jest.mock('~/alert');

const MOCK_VERIFY_CREDIT_CARD_PATH = '/mock/verify_credit_card/path';
const MOCK_VERIFY_CAPTCHA_PATH = '/mock/verify_credit_card_captcha/path';

describe('CreditCardVerification', () => {
  let trackingSpy;
  let wrapper;
  let axiosMock;

  const zuoraSubmitSpy = jest.fn();

  const findZuora = () => wrapper.findComponent(Zuora);
  const findSubmitButton = () => wrapper.findComponent('[type="submit"]');
  const findPhoneExemptionLink = () => wrapper.findComponentByTestId('verify-with-phone-btn');
  const findCaptcha = () => wrapper.findComponent(Captcha);

  const createComponent = ({ provide, props } = { provide: {}, props: {} }) => {
    wrapper = shallowMountExtended(CreditCardVerification, {
      provide: {
        creditCardVerifyPath: MOCK_VERIFY_CREDIT_CARD_PATH,
        creditCardVerifyCaptchaPath: MOCK_VERIFY_CAPTCHA_PATH,
        creditCard: {
          formId: 'form_id',
          userId: 927,
        },
        offerPhoneNumberExemption: true,
        ...provide,
      },
      propsData: { completed: false, ...props },
      stubs: {
        Zuora: stubComponent(Zuora, {
          methods: { submit: zuoraSubmitSpy },
        }),
        GlSprintf,
      },
    });

    trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
  };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.restore();
    createAlert.mockClear();
    unmockTracking();
  });

  it('renders the form', () => {
    createComponent();

    expect(findZuora().exists()).toBe(true);
    expect(findSubmitButton().exists()).toBe(true);
    expect(findSubmitButton().props('disabled')).toBe(true);
    expect(wrapper.text()).toContain('Having trouble? Contact support.');
    expect(wrapper.findComponent(GlLink).attributes('href')).toEqual(CONTACT_SUPPORT_URL);
  });

  describe('when zuora emits success', () => {
    describe('when check for reuse request returns a successful response', () => {
      beforeEach(() => {
        axiosMock.onGet(MOCK_VERIFY_CREDIT_CARD_PATH).reply(HTTP_STATUS_OK);

        createComponent();
        findZuora().vm.$emit('success');
      });

      it('displays loading state', () => {
        expect(findSubmitButton().props('loading')).toBe(true);
      });

      it('emits a completed event', async () => {
        await waitForPromises();

        expect(wrapper.emitted('completed')).toHaveLength(1);
      });

      it('tracks the event', async () => {
        await waitForPromises();

        expect(trackingSpy).toHaveBeenCalledTimes(1);
        expect(trackingSpy).toHaveBeenLastCalledWith(EVENT_CATEGORY, EVENT_SUCCESS, {
          category: EVENT_CATEGORY,
        });
      });
    });

    describe('when check for reuse request returns an error', () => {
      const message = 'There was a problem with the credit card details you entered.';

      beforeEach(async () => {
        axiosMock
          .onGet(MOCK_VERIFY_CREDIT_CARD_PATH)
          .reply(HTTP_STATUS_INTERNAL_SERVER_ERROR, { message, reason: RELATED_TO_BANNED_USER });

        createComponent();
        findZuora().vm.$emit('success');

        await waitForPromises();
      });

      it('does not emit a completed event', () => {
        expect(wrapper.emitted('completed')).toBeUndefined();
      });

      it('does not track a success event', () => {
        expect(trackingSpy).toHaveBeenCalledTimes(0);
      });

      it('re-displays the form and displays an alert with the returned message', async () => {
        expect(findSubmitButton().props('loading')).toBe(false);
        expect(findZuora().exists()).toBe(true);

        findZuora().vm.$emit('loading', false);

        await nextTick();

        expect(createAlert).toHaveBeenCalledWith({
          message,
        });
      });

      it('disables the submit button', () => {
        expect(findSubmitButton().props('disabled')).toBe(true);
      });

      describe('when there is no returned message data', () => {
        beforeEach(async () => {
          axiosMock.onGet(MOCK_VERIFY_CREDIT_CARD_PATH).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

          createComponent();
          findZuora().vm.$emit('success');

          await waitForPromises();
        });

        it('displays an alert with a generic message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: I18N_GENERIC_ERROR,
            captureError: true,
            error: expect.any(Error),
          });
        });
      });
    });
  });

  describe('when zuora emits load error', () => {
    it('disables the submit button', () => {
      createComponent();

      wrapper.findComponent(Zuora).vm.$emit('load-error');

      expect(findSubmitButton().props('disabled')).toBe(true);
    });
  });

  describe.each([
    [Event.SERVER_VALIDATION_ERROR, { message: 'server error' }],
    [Event.CLIENT_VALIDATION_ERROR, { message: 'client error' }],
  ])('when zuora emits %s', (event, payload) => {
    beforeEach(() => {
      createComponent();
      wrapper.findComponent(Zuora).vm.$emit(event, payload);
    });

    it('tracks the event', () => {
      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenLastCalledWith(EVENT_CATEGORY, EVENT_FAILED, {
        category: EVENT_CATEGORY,
        property: payload.message,
      });
    });
  });

  describe('clicking the submit button', () => {
    describe('when captcha is verified successfully', () => {
      beforeEach(() => {
        axiosMock.onPost(MOCK_VERIFY_CAPTCHA_PATH).reply(HTTP_STATUS_OK);

        createComponent({ props: { requireChallenge: true } });
        findSubmitButton().vm.$emit('click');
      });

      it('displays loading state', () => {
        expect(findSubmitButton().props('loading')).toBe(true);
      });

      it('calls the submit method of the Zuora component', async () => {
        await waitForPromises();

        expect(zuoraSubmitSpy).toHaveBeenCalled();
        expect(findSubmitButton().props('loading')).toBe(false);
      });
    });

    describe('when captcha could not be verified', () => {
      beforeEach(() => {
        axiosMock
          .onPost(MOCK_VERIFY_CAPTCHA_PATH)
          .reply(HTTP_STATUS_INTERNAL_SERVER_ERROR, { message: 'Complete verification' });

        createComponent({ props: { requireChallenge: true } });
        findSubmitButton().vm.$emit('click');
      });

      it('displays an alert with given error message', async () => {
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Complete verification',
        });
      });
    });
  });

  describe('submit button loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it("is disabled when Zuora component emits 'loading' event with true", async () => {
      findZuora().vm.$emit('loading', true);

      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it("is not disabled when <Zuora /> emits 'loading' event with false", async () => {
      findZuora().vm.$emit('loading', false);

      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(false);
    });
  });

  describe('when phone exemption is not offered', () => {
    beforeEach(() => {
      createComponent({ provide: { offerPhoneNumberExemption: false } });
    });

    it('does not show a link to request a phone exemption', () => {
      expect(findPhoneExemptionLink().exists()).toBe(false);
    });
  });

  describe('when phone exemption is offered', () => {
    beforeEach(() => {
      createComponent({ provide: { offerPhoneNumberExemption: true } });
    });

    it('shows a link to request a phone exemption', () => {
      expect(findPhoneExemptionLink().exists()).toBe(true);
    });

    it('emits an `exemption-requested` event when clicking the link', () => {
      findPhoneExemptionLink().vm.$emit('click');

      expect(wrapper.emitted('exemption-requested')).toHaveLength(1);
    });
  });

  describe('captcha', () => {
    beforeEach(() => {
      axiosMock.onPost(MOCK_VERIFY_CAPTCHA_PATH).reply(HTTP_STATUS_OK);

      createComponent({ props: { requireChallenge: true } });
    });

    it('renders the identity verification captcha component', () => {
      expect(findCaptcha().exists()).toBe(true);

      expect(findCaptcha().props()).toMatchObject({
        showArkoseChallenge: true,
        verificationAttempts: 0,
      });
    });

    describe('when `captcha-shown` event is emitted', () => {
      it('disables the submit button', async () => {
        findZuora().vm.$emit('loading', false);

        await nextTick();

        expect(findSubmitButton().props('disabled')).toBe(false);

        findCaptcha().vm.$emit('captcha-shown');

        await nextTick();

        expect(findSubmitButton().props('disabled')).toBe(true);
      });
    });

    describe('when `captcha-solved` event is emitted', () => {
      it('calls verify captcha with the correct data', async () => {
        findCaptcha().vm.$emit('captcha-solved', { captcha_token: '1234' });

        findSubmitButton().vm.$emit('click');
        await waitForPromises();

        expect(axiosMock.history.post[0].data).toBe(JSON.stringify({ captcha_token: '1234' }));
      });
    });

    describe('when `captcha-reset` event is emitted', () => {
      it('disables the submit button', async () => {
        findZuora().vm.$emit('loading', false);

        await nextTick();

        expect(findSubmitButton().props('disabled')).toBe(false);

        findCaptcha().vm.$emit('captcha-reset');

        await nextTick();

        expect(findSubmitButton().props('disabled')).toBe(true);
      });
    });
  });
});
