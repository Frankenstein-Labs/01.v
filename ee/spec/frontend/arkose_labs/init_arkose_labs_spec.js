import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';
import { initArkoseLabsChallenge, resetArkoseLabsChallenge } from 'ee/arkose_labs/init_arkose_labs';
import * as ColorUtils from '~/lib/utils/color_utils';

jest.mock('lodash-es', () => ({ ...jest.requireActual('lodash-es'), uniqueId: (x) => `${x}7` }));

const EXPECTED_CALLBACK_NAME = '_initArkoseLabsScript_callback_7';
const MOCK_PUBLIC_KEY = 'arkose-labs-public-api-key';
const MOCK_DOMAIN = 'client-api.arkoselabs.com';
const MOCK_DATA_EXCHANGE_PAYLOAD = 'fakeDataExchangePayload';
const MOCK_DATA_EXCHANGE_PAYLOAD_PATH = '/path/to/data_exchange_payload';

let axiosMock;

beforeEach(() => {
  axiosMock = new MockAdapter(axios);
});

afterEach(() => {
  axiosMock.restore();
});

describe('initArkoseLabsChallenge', () => {
  let subject;

  const initSubject = (
    args = { dataExchangePayload: undefined, dataExchangePayloadPath: undefined, config: {} },
  ) => {
    subject = initArkoseLabsChallenge({
      publicKey: MOCK_PUBLIC_KEY,
      domain: MOCK_DOMAIN,
      ...args,
    });
  };

  const findScriptTags = () => document.querySelectorAll('script');

  afterEach(() => {
    subject = null;
    document.getElementsByTagName('html')[0].innerHTML = '';
  });

  it('sets a global enforcement callback', () => {
    initSubject();

    expect(window[EXPECTED_CALLBACK_NAME]).not.toBe(undefined);
  });

  it('adds ArkoseLabs scripts to the HTML head', () => {
    expect(findScriptTags()).toHaveLength(0);

    initSubject();

    const scriptTag = findScriptTags().item(0);

    expect(scriptTag.getAttribute('type')).toBe('text/javascript');
    expect(scriptTag.getAttribute('src')).toBe(
      `https://${MOCK_DOMAIN}/v2/${MOCK_PUBLIC_KEY}/api.js`,
    );
    expect(scriptTag.dataset.callback).toBe(EXPECTED_CALLBACK_NAME);
    expect(scriptTag.getAttribute('id')).toBe('arkose-challenge-script');
  });

  describe('when callback is called', () => {
    const enforcement = { setConfig: jest.fn() };
    const config = { a: 'a', b: 'b' };
    const expectedSetConfigArgs = (dataExchangePayload) => {
      const baseArgs = { mode: 'inline', ...config, styleTheme: null };
      return dataExchangePayload ? { data: { blob: dataExchangePayload }, ...baseArgs } : baseArgs;
    };

    it('when callback is called, cleans up the global object and resolves the Promise', () => {
      initSubject();
      window[EXPECTED_CALLBACK_NAME](enforcement);

      expect(window[EXPECTED_CALLBACK_NAME]).toBe(undefined);
      return expect(subject).resolves.toBe(enforcement);
    });

    it('calls ArkoseLabs config object setDefault with defaults and passed in options', async () => {
      initSubject({ dataExchangePayload: undefined, config });
      window[EXPECTED_CALLBACK_NAME](enforcement);

      await expect(subject).resolves.toBe(enforcement);
      expect(enforcement.setConfig).toHaveBeenCalledWith({
        mode: 'inline',
        ...config,
        styleTheme: null,
      });
    });

    describe('when dataExchangePayload is passed in', () => {
      it('calls ArkoseLabs config object setDefault with defaults, , data: { blob: dataExchangePayload }, and passed in options', async () => {
        const dataExchangePayload = 'payload';
        initSubject({ dataExchangePayload, config });
        window[EXPECTED_CALLBACK_NAME](enforcement);

        await expect(subject).resolves.toBe(enforcement);
        expect(enforcement.setConfig).toHaveBeenCalledWith(
          expectedSetConfigArgs(dataExchangePayload),
        );
      });
    });

    describe('when dataExchangePayloadPath is passed in', () => {
      describe('when request to fetch data exchange payload succeeds', () => {
        beforeEach(() => {
          axiosMock
            .onGet(MOCK_DATA_EXCHANGE_PAYLOAD_PATH)
            .reply(HTTP_STATUS_OK, { payload: MOCK_DATA_EXCHANGE_PAYLOAD });
        });

        it('calls ArkoseLabs config object setConfig with the data value', async () => {
          initSubject({
            dataExchangePayloadPath: MOCK_DATA_EXCHANGE_PAYLOAD_PATH,
            dataExchangePayload: 'not used',
            config,
          });
          window[EXPECTED_CALLBACK_NAME](enforcement);

          await expect(subject).resolves.toBe(enforcement);
          expect(enforcement.setConfig).toHaveBeenCalledWith(
            expectedSetConfigArgs(MOCK_DATA_EXCHANGE_PAYLOAD),
          );
        });
      });

      describe('when request to fetch data exchange fails', () => {
        beforeEach(() => {
          axiosMock.onGet(MOCK_DATA_EXCHANGE_PAYLOAD_PATH).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        });

        it('calls ArkoseLabs config object setConfig without data value', async () => {
          initSubject({
            dataExchangePayloadPath: MOCK_DATA_EXCHANGE_PAYLOAD_PATH,
            dataExchangePayload: 'not used',
            config,
          });
          window[EXPECTED_CALLBACK_NAME](enforcement);

          await expect(subject).resolves.toBe(enforcement);
          expect(enforcement.setConfig).toHaveBeenCalledWith(expectedSetConfigArgs(undefined));
        });
      });
    });

    describe('dark mode', () => {
      it('sets styleTheme to dark when dark mode is enabled', async () => {
        jest.spyOn(ColorUtils, 'darkModeEnabled').mockImplementation(() => true);

        initSubject({ config: {} });
        window[EXPECTED_CALLBACK_NAME](enforcement);

        await expect(subject).resolves.toBe(enforcement);
        expect(enforcement.setConfig).toHaveBeenCalledWith(
          expect.objectContaining({ styleTheme: 'dark' }),
        );
      });

      it('sets styleTheme to null when dark mode is disabled', async () => {
        jest.spyOn(ColorUtils, 'darkModeEnabled').mockImplementation(() => false);

        initSubject({ config: {} });
        window[EXPECTED_CALLBACK_NAME](enforcement);

        await expect(subject).resolves.toBe(enforcement);
        expect(enforcement.setConfig).toHaveBeenCalledWith(
          expect.objectContaining({ styleTheme: null }),
        );
      });

      it('allows explicit styleTheme to override dark mode detection', async () => {
        jest.spyOn(ColorUtils, 'darkModeEnabled').mockImplementation(() => true);

        initSubject({ config: { styleTheme: 'light' } });
        window[EXPECTED_CALLBACK_NAME](enforcement);

        await expect(subject).resolves.toBe(enforcement);
        expect(enforcement.setConfig).toHaveBeenCalledWith(
          expect.objectContaining({ styleTheme: 'light' }),
        );
      });
    });
  });

  it('rejects the promise when script fails to load', () => {
    initSubject();

    const scriptTag = findScriptTags().item(0);
    const error = new Error();
    scriptTag.onerror(error);

    return expect(subject).rejects.toThrow(error);
  });

  it('only creates one script tag', () => {
    initSubject();
    initSubject();

    expect(findScriptTags()).toHaveLength(1);
  });
});

describe('resetArkoseLabsChallenge', () => {
  const arkoseObject = { setConfig: jest.fn(), reset: jest.fn() };

  it('calls reset on the Arkose object', async () => {
    await expect(resetArkoseLabsChallenge(arkoseObject)).resolves.toBe(undefined);
    expect(arkoseObject.reset).toHaveBeenCalled();
  });

  describe('when dataExchangePayloadPath is passed in', () => {
    describe('when request to fetch data exchange payload succeeds', () => {
      beforeEach(() => {
        axiosMock
          .onGet(MOCK_DATA_EXCHANGE_PAYLOAD_PATH)
          .reply(HTTP_STATUS_OK, { payload: MOCK_DATA_EXCHANGE_PAYLOAD });
      });

      it('calls setConfig on the Arkose object with the fetched payload', async () => {
        await expect(
          resetArkoseLabsChallenge(arkoseObject, MOCK_DATA_EXCHANGE_PAYLOAD_PATH),
        ).resolves.toBe(undefined);
        expect(arkoseObject.setConfig).toHaveBeenCalledWith({
          data: { blob: MOCK_DATA_EXCHANGE_PAYLOAD },
        });
      });
    });

    describe('when request to fetch data exchange fails', () => {
      beforeEach(() => {
        axiosMock.onGet(MOCK_DATA_EXCHANGE_PAYLOAD_PATH).reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      });

      it('calls reset on the Arkose object', async () => {
        await expect(resetArkoseLabsChallenge(arkoseObject)).resolves.toBe(undefined);
        expect(arkoseObject.reset).toHaveBeenCalled();
      });

      it('does not call setConfig on the Arkose object', async () => {
        await expect(
          resetArkoseLabsChallenge(arkoseObject, MOCK_DATA_EXCHANGE_PAYLOAD_PATH),
        ).resolves.toBe(undefined);
        expect(arkoseObject.setConfig).not.toHaveBeenCalled();
      });
    });
  });
});
