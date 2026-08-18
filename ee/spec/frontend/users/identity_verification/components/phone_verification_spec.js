import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import axios from '~/lib/utils/axios_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PhoneVerification from 'ee/users/identity_verification/components/phone_verification.vue';
import InternationalPhoneInput from 'ee/users/identity_verification/components/international_phone_input.vue';
import VerifyPhoneVerificationCode from 'ee/users/identity_verification/components/verify_phone_verification_code.vue';
import Captcha from 'ee/users/identity_verification/components/identity_verification_captcha.vue';
import { calculateRemainingMilliseconds } from '~/lib/utils/datetime_utility';
import { HTTP_STATUS_OK, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';
import Poll from '~/lib/utils/poll';
import { createAlert, VARIANT_INFO } from '~/alert';

jest.mock('~/lib/utils/datetime_utility', () => ({
  ...jest.requireActual('~/lib/utils/datetime_utility'),
  calculateRemainingMilliseconds: jest.fn(),
}));
jest.mock('~/alert');

describe('Phone Verification component', () => {
  let wrapper;
  let axiosMock;

  const PHONE_NUMBER = {
    country: 'US',
    internationalDialCode: '1',
    number: '555',
  };

  const DEFAULT_PROVIDE = {
    verificationStatePath: '/users/identity_verification/verification_state',
    offerPhoneNumberExemption: true,
    phoneNumber: undefined,
  };

  const findInternationalPhoneInput = () => wrapper.findComponent(InternationalPhoneInput);
  const findVerifyCodeInput = () => wrapper.findComponent(VerifyPhoneVerificationCode);
  const findPhoneExemptionLink = () => wrapper.findComponentByTestId('verify-with-card-btn');

  const findCaptcha = () => findInternationalPhoneInput().findComponent(Captcha);

  const createComponent = (provide = {}, props = {}) => {
    wrapper = shallowMountExtended(PhoneVerification, {
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      propsData: { requireChallenge: true, ...props },
    });
  };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    calculateRemainingMilliseconds.mockReturnValue(1000);

    createComponent();
  });

  describe('When component loads', () => {
    const expectedProps = {
      sendCodeAllowed: true,
      sendCodeAllowedAfter: null,
    };

    it('renders InternationalPhoneInput component with the correct props', () => {
      const component = findInternationalPhoneInput();
      expect(component.exists()).toBe(true);
      expect(component.props()).toMatchObject(expectedProps);
    });

    it('does not render VerifyPhoneVerificationCode component', () => {
      expect(findVerifyCodeInput().exists()).toBe(false);
    });

    describe('rendered InternationalPhoneInput component', () => {
      const expectCorrectProps = (expected) => {
        it('has the correct props', () => {
          expect(findInternationalPhoneInput().props()).toMatchObject(expected);
        });
      };

      describe('when sendAllowedAfter is a valid timestamp in the future', () => {
        beforeEach(() => {
          createComponent({ phoneNumber: { sendAllowedAfter: '2000-01-01T01:02:03Z' } });
        });

        expectCorrectProps({
          sendCodeAllowed: false,
          sendCodeAllowedAfter: '2000-01-01T01:02:03Z',
        });

        describe('when InternationalPhoneInput emits a `timer-expired` event', () => {
          beforeEach(async () => {
            findInternationalPhoneInput().vm.$emit('timer-expired');
            await nextTick();
          });

          expectCorrectProps(expectedProps);
        });
      });

      describe('when sendAllowedAfter is a valid timestamp in the past', () => {
        beforeEach(() => {
          calculateRemainingMilliseconds.mockReturnValue(0);
          createComponent({ phoneNumber: { sendAllowedAfter: '2000-01-01T01:02:03Z' } });
        });

        expectCorrectProps({
          sendCodeAllowed: true,
          sendCodeAllowedAfter: '2000-01-01T01:02:03Z',
        });
      });

      describe('when sendAllowedAfter is not a valid timestamp', () => {
        beforeEach(() => {
          createComponent({ phoneNumber: { sendAllowedAfter: 'not-a-date' } });
        });

        expectCorrectProps(expectedProps);
      });
    });
  });

  describe('On next', () => {
    beforeEach(async () => {
      await findInternationalPhoneInput().vm.$emit('next', {
        ...PHONE_NUMBER,
        sendAllowedAfter: '2000-01-01T01:02:03Z',
      });
    });

    it('updates sendCodeAllowed and sendCodeAllowedAfter props of VerifyPhoneVerificationCode', () => {
      const expectedProps = {
        sendCodeAllowed: false,
        sendCodeAllowedAfter: '2000-01-01T01:02:03Z',
      };
      expect(findVerifyCodeInput().props()).toMatchObject(expectedProps);
    });

    it('should hide InternationalPhoneInput component', () => {
      expect(findInternationalPhoneInput().exists()).toBe(false);
    });

    it('should display VerifyPhoneVerificationCode component', () => {
      expect(findVerifyCodeInput().exists()).toBe(true);
      expect(findVerifyCodeInput().props()).toMatchObject({ latestPhoneNumber: PHONE_NUMBER });
    });

    describe('when VerifyPhoneVerificationCode emits a `timer-expired` event', () => {
      beforeEach(async () => {
        findVerifyCodeInput().vm.$emit('timer-expired');
        await nextTick();
      });

      it('has the correct props', () => {
        expect(findVerifyCodeInput().props()).toMatchObject({
          sendCodeAllowed: true,
          sendCodeAllowedAfter: null,
        });
      });
    });

    describe('when VerifyPhoneVerificationCode emits a `resent` event', () => {
      beforeEach(async () => {
        findVerifyCodeInput().vm.$emit('resent', '2001-12-31:00:00Z');
        await nextTick();
      });

      it('has the correct props', () => {
        expect(findVerifyCodeInput().props()).toMatchObject({
          sendCodeAllowed: false,
          sendCodeAllowedAfter: '2001-12-31:00:00Z',
        });
      });
    });

    describe('On back', () => {
      beforeEach(() => {
        findVerifyCodeInput().vm.$emit('back');
        return nextTick();
      });

      it('should display InternationalPhoneInput component', () => {
        expect(findInternationalPhoneInput().exists()).toBe(true);
      });

      it('should hide PhoneVerificationCodeInput component', () => {
        expect(findVerifyCodeInput().exists()).toBe(false);
      });
    });
  });

  describe('On verified', () => {
    beforeEach(async () => {
      findInternationalPhoneInput().vm.$emit('next', PHONE_NUMBER);
      await nextTick();

      findVerifyCodeInput().vm.$emit('verified');
      return nextTick();
    });

    it('should emit completed event', () => {
      expect(wrapper.emitted('completed')).toHaveLength(1);
    });
  });

  describe('On skip-verification', () => {
    beforeEach(() => {
      findInternationalPhoneInput().vm.$emit('skip-verification');
      return nextTick();
    });

    it('should emit completed event', () => {
      expect(wrapper.emitted('completed')).toHaveLength(1);
    });
  });

  describe('when phone exemption is not offered', () => {
    beforeEach(() => {
      createComponent({ offerPhoneNumberExemption: false });
    });

    it('does not show a link to request a phone exemption', () => {
      expect(findPhoneExemptionLink().exists()).toBe(false);
    });
  });

  describe('when phone exemption is offered', () => {
    it('shows a link to request a phone exemption', () => {
      expect(findPhoneExemptionLink().exists()).toBe(true);
    });

    it('emits an `exemption-requested` event when clicking the link', () => {
      findPhoneExemptionLink().vm.$emit('click');

      expect(wrapper.emitted('exemption-requested')).toHaveLength(1);
    });
  });

  describe('Captcha', () => {
    it('renders the phone verification captcha component', () => {
      expect(findCaptcha().exists()).toBe(true);

      expect(findCaptcha().props()).toMatchObject({
        showArkoseChallenge: true,
        verificationAttempts: 0,
      });
    });

    describe('when requireChallenge prop is false', () => {
      it('passes it as a prop to phone verification captcha component', () => {
        createComponent({}, { requireChallenge: false });

        expect(findCaptcha().props()).toMatchObject({
          showArkoseChallenge: false,
        });
      });
    });

    describe('when `verification-attempt` event is emitted', () => {
      it('passes it as a prop to phone verification captcha component', async () => {
        findInternationalPhoneInput().vm.$emit('verification-attempt');
        await nextTick();

        expect(findCaptcha().props()).toMatchObject({
          verificationAttempts: 1,
        });
      });
    });

    describe('when `captcha-shown` event is emitted', () => {
      it('passes disableSubmitButton prop as true', async () => {
        findCaptcha().vm.$emit('captcha-shown');
        await nextTick();

        expect(findInternationalPhoneInput().props()).toMatchObject({
          disableSubmitButton: true,
        });
      });
    });

    describe('when `captcha-solved` event is emitted', () => {
      it('passes correct props', async () => {
        findCaptcha().vm.$emit('captcha-solved', { captcha_token: '1234' });
        await nextTick();

        expect(findInternationalPhoneInput().props()).toMatchObject({
          disableSubmitButton: false,
          additionalRequestParams: { captcha_token: '1234' },
        });
      });
    });

    describe('when `captcha-reset` event is emitted', () => {
      it('passes correct props', async () => {
        findCaptcha().vm.$emit('captcha-reset');
        await nextTick();

        expect(findInternationalPhoneInput().props()).toMatchObject({
          disableSubmitButton: true,
          additionalRequestParams: {},
        });
      });
    });
  });

  describe('Verification state polling', () => {
    const pollInterval = 10;

    let pollRequest;
    let pollStop;

    const mockVerificationState = (mockState) => {
      const data = {
        verification_methods: Object.keys(mockState),
        verification_state: mockState,
      };
      axiosMock
        .onGet(DEFAULT_PROVIDE.verificationStatePath)
        .reply(HTTP_STATUS_OK, data, { 'poll-interval': pollInterval });

      return data;
    };

    const setupComponent = async (provide = {}) => {
      createComponent(provide);

      await findInternationalPhoneInput().vm.$emit('next', {
        ...PHONE_NUMBER,
        sendAllowedAfter: '2000-01-01T01:02:03Z',
      });
    };

    beforeEach(() => {
      pollRequest = jest.spyOn(Poll.prototype, 'makeRequest');
      pollStop = jest.spyOn(Poll.prototype, 'stop');
    });

    afterEach(() => {
      pollRequest.mockRestore();
      pollStop.mockRestore();
      axiosMock.restore();
      createAlert.mockClear();
    });

    describe('when request succeeds', () => {
      it('emits set-verification-state with response data then stops', async () => {
        mockVerificationState({ phone: false });

        setupComponent();

        jest.advanceTimersByTime(5000);
        await axios.waitForAll();

        expect(pollRequest).toHaveBeenCalledTimes(1);
        expect(pollStop).not.toHaveBeenCalled();
        expect(wrapper.emitted('set-verification-state')).toBeUndefined();

        const responseData = mockVerificationState({});
        mockVerificationState({});

        jest.advanceTimersByTime(pollInterval);
        await axios.waitForAll();

        expect(pollRequest).toHaveBeenCalledTimes(2);
        expect(pollStop).toHaveBeenCalledTimes(1);
        expect(wrapper.emitted('set-verification-state')).toStrictEqual([[responseData]]);
        expect(createAlert).toHaveBeenCalledWith({
          message:
            'Phone number verification is unavailable at this time. Please verify with a credit card instead.',
          variant: VARIANT_INFO,
        });

        jest.advanceTimersByTime(pollInterval);
        await axios.waitForAll();

        expect(pollRequest).toHaveBeenCalledTimes(2);
        expect(pollStop).toHaveBeenCalledTimes(1);
        expect(wrapper.emitted('set-verification-state')).toStrictEqual([[responseData]]);
      });
    });

    describe('when request fails', () => {
      it('stops', async () => {
        axiosMock
          .onGet(DEFAULT_PROVIDE.verificationStatePath)
          .reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);

        setupComponent();

        jest.advanceTimersByTime(5000);
        await axios.waitForAll();

        expect(pollRequest).toHaveBeenCalledTimes(1);
        expect(pollStop).toHaveBeenCalledTimes(1);
        expect(wrapper.emitted('set-verification-state')).toBeUndefined();
      });
    });
  });
});
