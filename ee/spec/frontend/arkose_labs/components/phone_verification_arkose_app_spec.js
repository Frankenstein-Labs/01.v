import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PhoneVerificationArkoseApp from 'ee/arkose_labs/components/phone_verification_arkose_app.vue';
import { initArkoseLabsChallenge, resetArkoseLabsChallenge } from 'ee/arkose_labs/init_arkose_labs';
import { logError } from '~/lib/logger';

jest.mock('~/lib/logger');
jest.mock('ee/arkose_labs/init_arkose_labs');
let onShown;
let onCompleted;

const MOCK_ARKOSE_RESPONSE = { token: 'verification-token' };
const MOCK_PUBLIC_KEY = 'arkose-labs-public-api-key';
const MOCK_DOMAIN = 'client-api.arkoselabs.com';
const MOCK_DATA_EXCHANGE_PAYLOAD = 'fakeDataExchangePayload';
const MOCK_DATA_EXCHANGE_PAYLOAD_PATH = '/path/to/data_exchange_payload';
const MOCK_ARKOSE_OBJECT = 'mockArkoseObject';

initArkoseLabsChallenge.mockImplementation(({ config }) => {
  onShown = config.onShown;
  onCompleted = config.onCompleted;

  return MOCK_ARKOSE_OBJECT;
});

describe('PhoneVerificationArkoseApp', () => {
  let wrapper;

  const findChallengeContainer = () => wrapper.findByTestId('arkose-labs-challenge');

  const createComponent = ({ provide } = { provide: {} }) => {
    wrapper = mountExtended(PhoneVerificationArkoseApp, {
      provide: {
        arkoseConfiguration: {
          apiKey: MOCK_PUBLIC_KEY,
          domain: MOCK_DOMAIN,
          dataExchangePayloadPath: MOCK_DATA_EXCHANGE_PAYLOAD_PATH,
        },
        arkoseDataExchangePayload: MOCK_DATA_EXCHANGE_PAYLOAD,
        ...provide,
      },
      propsData: { resetSession: false },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('should initialise the arkose labs script', () => {
    expect(initArkoseLabsChallenge).toHaveBeenCalledWith({
      publicKey: MOCK_PUBLIC_KEY,
      domain: MOCK_DOMAIN,
      dataExchangePayload: MOCK_DATA_EXCHANGE_PAYLOAD,
      dataExchangePayloadPath: MOCK_DATA_EXCHANGE_PAYLOAD_PATH,
      config: expect.objectContaining({
        onShown: expect.any(Function),
        onCompleted: expect.any(Function),
      }),
    });
  });

  it('should show the challenge container when arkose script calls `onShown`', async () => {
    expect(findChallengeContainer().isVisible()).toBe(false);

    onShown();
    await nextTick();

    expect(findChallengeContainer().isVisible()).toBe(true);
  });

  it('should emit `challenge-solved` event when arkose challenge is solved', async () => {
    onShown();
    onCompleted(MOCK_ARKOSE_RESPONSE);

    await nextTick();

    expect(wrapper.emitted('challenge-solved')).toStrictEqual([[MOCK_ARKOSE_RESPONSE.token]]);
  });

  it('should call reset when resetSession is set to true', async () => {
    // setProps is justified here because we are testing the component's
    // reactive behavior which constitutes an exception
    // See https://docs.gitlab.com/ee/development/fe_guide/style/vue.html#setting-component-state

    await wrapper.setProps({
      resetSession: true,
    });

    expect(resetArkoseLabsChallenge).toHaveBeenCalledWith(MOCK_ARKOSE_OBJECT);
  });

  describe('when challenge initialization fails', () => {
    const arkoseError = new Error();

    beforeEach(() => {
      initArkoseLabsChallenge.mockImplementation(() => {
        throw arkoseError;
      });

      createComponent();
    });

    it('logs the error', () => {
      expect(logError).toHaveBeenCalledWith('ArkoseLabs initialization error', arkoseError);
    });
  });
});
