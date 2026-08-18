import { nextTick } from 'vue';
import { GlForm, GlLoadingIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import IdentityVerificationArkoseApp from 'ee/arkose_labs/components/identity_verification_arkose_app.vue';
import { initArkoseLabsChallenge } from 'ee/arkose_labs/init_arkose_labs';
import { VERIFICATION_TOKEN_INPUT_NAME, CHALLENGE_CONTAINER_CLASS } from 'ee/arkose_labs/constants';
import { logError } from '~/lib/logger';

jest.mock('~/lib/utils/csrf', () => ({ token: 'mock-csrf-token' }));
jest.mock('ee/arkose_labs/init_arkose_labs');
jest.mock('~/lib/logger');

let onShown;
let onCompleted;

const mockDataExchangePayload = 'fakeDataExchangePayload';
const mockDataExchangePayloadPath = '/path/to/data_exchange_payload';
initArkoseLabsChallenge.mockImplementation(({ config }) => {
  onShown = config.onShown;
  onCompleted = config.onCompleted;
});

const MOCK_ARKOSE_RESPONSE = { token: 'verification-token' };
const MOCK_PUBLIC_KEY = 'arkose-labs-public-api-key';
const MOCK_DOMAIN = 'client-api.arkoselabs.com';
const MOCK_SESSION_VERIFICATION_PATH = '/session/verification/path';

describe('IdentityVerificationArkoseApp', () => {
  let wrapper;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findForm = () => wrapper.findComponent(GlForm);
  const findArkoseLabsVerificationTokenInput = () =>
    findForm().find(`input[name="${VERIFICATION_TOKEN_INPUT_NAME}"]`);

  const createComponent = ({ props } = { props: {} }) => {
    wrapper = mount(IdentityVerificationArkoseApp, {
      propsData: {
        publicKey: MOCK_PUBLIC_KEY,
        domain: MOCK_DOMAIN,
        dataExchangePayload: mockDataExchangePayload,
        dataExchangePayloadPath: mockDataExchangePayloadPath,
        sessionVerificationPath: MOCK_SESSION_VERIFICATION_PATH,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('initializes Arkose Labs challenge', () => {
    expect(initArkoseLabsChallenge).toHaveBeenCalledWith({
      publicKey: MOCK_PUBLIC_KEY,
      domain: MOCK_DOMAIN,
      dataExchangePayload: mockDataExchangePayload,
      dataExchangePayloadPath: mockDataExchangePayloadPath,
      config: expect.objectContaining({
        selector: `.${CHALLENGE_CONTAINER_CLASS}`,
        onShown: expect.any(Function),
        onCompleted: expect.any(Function),
      }),
    });
  });

  it('renders the challenge container', () => {
    expect(wrapper.find(`.${CHALLENGE_CONTAINER_CLASS}`).exists()).toBe(true);
  });

  describe('rendered form', () => {
    it('has the correct attributes', () => {
      const form = findForm();
      expect(form.attributes('action')).toBe(MOCK_SESSION_VERIFICATION_PATH);
      expect(form.attributes('method')).toBe('post');
    });

    it('contains a hidden input for the verification token', () => {
      const input = findArkoseLabsVerificationTokenInput();

      expect(input.attributes('type')).toBe('hidden');
      expect(input.element.value).toBe('');
    });

    it('contains a hidden input for the authenticity_token', () => {
      const input = findForm().find('input[name="authenticity_token"]');
      expect(input.attributes('type')).toBe('hidden');
      expect(input.attributes('value')).toBe('mock-csrf-token');
    });
  });

  it('shows a loading icon and removes it when Arkose Labs calls `onShown`', async () => {
    expect(findLoadingIcon().exists()).toBe(true);

    onShown();
    await nextTick();

    expect(findLoadingIcon().exists()).toBe(false);
  });

  describe('when Arkose Labs calls `onCompleted`', () => {
    let formSubmitSpy;

    beforeEach(() => {
      formSubmitSpy = jest.spyOn(findForm().element, 'submit');

      onCompleted(MOCK_ARKOSE_RESPONSE);
    });

    it("sets the verification token input's value", () => {
      expect(findArkoseLabsVerificationTokenInput().element.value).toBe(MOCK_ARKOSE_RESPONSE.token);
    });

    it('submits the form', () => {
      expect(formSubmitSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe('when challenge initialization fails', () => {
    let formSubmitSpy;
    const arkoseError = new Error();

    beforeEach(() => {
      initArkoseLabsChallenge.mockImplementation(() => {
        throw arkoseError;
      });

      createComponent();

      formSubmitSpy = jest.spyOn(findForm().element, 'submit');
    });

    it('logs the error', () => {
      expect(logError).toHaveBeenCalledWith('ArkoseLabs initialization error', arkoseError);
    });

    it('submits the form', () => {
      expect(formSubmitSpy).toHaveBeenCalled();
    });
  });
});
