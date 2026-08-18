import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import SignUpArkoseApp from './components/sign_up_arkose_app.vue';
import IdentityVerificationArkoseApp from './components/identity_verification_arkose_app.vue';

const FORM_SELECTOR = '.js-arkose-labs-form';

export const setupArkoseLabsForSignup = () => {
  const el = document.querySelector('#js-arkose-labs-challenge');

  if (!el) {
    return null;
  }

  const { apiKey, domain, dataExchangePayload } = el.dataset;

  return initVueApp({
    el,
    name: 'SignUpArkoseAppRoot',
    component: SignUpArkoseApp,
    props: {
      formSelector: FORM_SELECTOR,
      publicKey: apiKey,
      domain,
      dataExchangePayload,
    },
  });
};

export const setupArkoseLabsForIdentityVerification = () => {
  const el = document.querySelector('#js-arkose-labs-challenge');

  if (!el) {
    return null;
  }

  const { apiKey, domain, sessionVerificationPath, dataExchangePayload, dataExchangePayloadPath } =
    el.dataset;

  return initVueApp({
    el,
    name: 'IdentityVerificationArkoseAppRoot',
    component: IdentityVerificationArkoseApp,
    props: {
      publicKey: apiKey,
      domain,
      sessionVerificationPath,
      dataExchangePayload,
      dataExchangePayloadPath,
    },
  });
};
