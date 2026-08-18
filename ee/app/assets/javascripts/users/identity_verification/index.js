import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import IdentityVerificationWizard from './components/wizard.vue';

export const initIdentityVerification = () => {
  const el = document.getElementById('js-identity-verification');

  if (!el) return false;

  const {
    email,
    emailVerificationMessage,
    creditCard,
    phoneNumber,
    offerPhoneNumberExemption,
    verificationStatePath,
    phoneSendCodePath,
    phoneVerifyCodePath,
    phoneExemptionPath,
    creditCardVerifyPath,
    creditCardVerifyCaptchaPath,
    arkose,
    arkoseDataExchangePayload,
    successfulVerificationPath,
    unifiedRegistration,
  } = convertObjectPropsToCamelCase(JSON.parse(el.dataset.data), { deep: true });

  return initVueApp({
    el,
    apolloProvider,
    name: 'IdentityVerificationRoot',
    provide: {
      email,
      emailVerificationMessage,
      creditCard,
      phoneNumber,
      offerPhoneNumberExemption,
      verificationStatePath,
      phoneSendCodePath,
      phoneVerifyCodePath,
      phoneExemptionPath,
      creditCardVerifyPath,
      creditCardVerifyCaptchaPath,
      arkoseConfiguration: arkose,
      arkoseDataExchangePayload,
      successfulVerificationPath,
      unifiedRegistration,
    },
    component: IdentityVerificationWizard,
  });
};
