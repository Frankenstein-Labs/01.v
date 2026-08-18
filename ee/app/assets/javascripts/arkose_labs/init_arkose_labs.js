import { uniqueId } from 'lodash-es';
import axios from '~/lib/utils/axios_utils';
import { darkModeEnabled } from '~/lib/utils/color_utils';

const CALLBACK_NAME = '_initArkoseLabsScript_callback_';

const getCallbackName = () => uniqueId(CALLBACK_NAME);

const initArkoseLabsScript = ({ publicKey, domain }) => {
  const callbackFunctionName = getCallbackName();

  return new Promise((resolve, reject) => {
    window[callbackFunctionName] = (enforcement) => {
      delete window[callbackFunctionName];
      resolve(enforcement);
    };

    // in case the challenge needs to be loaded twice in the same Vue app, such as phone verification
    const element = document.getElementById('arkose-challenge-script');
    if (element) element.remove();

    const tag = document.createElement('script');
    [
      ['type', 'text/javascript'],
      ['src', `https://${domain}/v2/${publicKey}/api.js`],
      ['data-callback', callbackFunctionName],
      ['id', 'arkose-challenge-script'],
    ].forEach(([attr, value]) => {
      tag.setAttribute(attr, value);
    });

    tag.onerror = (error) => {
      reject(error);
    };

    document.head.appendChild(tag);
  });
};

const configureArkoseLabs = (configObject, dataExchangePayload, options = {}) => {
  const blob = dataExchangePayload;
  const data = blob ? { data: { blob } } : {};

  configObject.setConfig({
    mode: 'inline',
    ...data,
    ...options,
  });
};

const fetchDataExchangePayload = async (path) => {
  try {
    const response = await axios.get(path);
    return response.data?.payload;
  } catch {
    return undefined;
  }
};

export const initArkoseLabsChallenge = async ({
  publicKey,
  domain,
  dataExchangePayloadPath,
  config,
  ...rest
}) => {
  const dataExchangePayloadPromise = dataExchangePayloadPath
    ? fetchDataExchangePayload(dataExchangePayloadPath)
    : rest.dataExchangePayload;

  const initArkoseLabsScriptPromise = initArkoseLabsScript({ publicKey, domain });

  const dataExchangePayload = await dataExchangePayloadPromise;
  const arkoseObject = await initArkoseLabsScriptPromise;

  const finalConfig = {
    ...config,
    styleTheme: config.styleTheme ?? (darkModeEnabled() ? 'dark' : null),
  };

  configureArkoseLabs(arkoseObject, dataExchangePayload, finalConfig);

  return arkoseObject;
};

export const resetArkoseLabsChallenge = async (arkoseObject, dataExchangePayloadPath) => {
  const dataExchangePayloadPromise = dataExchangePayloadPath
    ? fetchDataExchangePayload(dataExchangePayloadPath)
    : undefined;

  const dataExchangePayload = await dataExchangePayloadPromise;

  arkoseObject.reset();

  if (dataExchangePayload) {
    arkoseObject.setConfig({ data: { blob: dataExchangePayload } });
  }
};
