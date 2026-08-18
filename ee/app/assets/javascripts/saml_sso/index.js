import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import { parseBoolean } from '~/lib/utils/common_utils';
import SamlAuthorize from './components/saml_authorize.vue';
import SamlReloadModal from './components/saml_reload_modal.vue';
import { AUTO_REDIRECT_TO_PROVIDER_BUTTON_SELECTOR, SAML_AUTHORIZE_SELECTOR } from './constants';

export const redirectUserWithSSOIdentity = () => {
  const signInButton = document.querySelector(AUTO_REDIRECT_TO_PROVIDER_BUTTON_SELECTOR);

  if (!signInButton) {
    return;
  }

  signInButton.click();
};

export const initSamlAuthorize = () => {
  const el = document.getElementById(SAML_AUTHORIZE_SELECTOR);

  if (!el) return null;

  const { groupName, groupUrl, rememberable, samlUrl, signInButtonText } = el.dataset;

  return initVueApp({
    el,
    name: 'SamlAuthorizeRoot',
    provide: {
      groupName,
      groupUrl,
      rememberable: parseBoolean(rememberable),
      samlUrl,
      signInButtonText,
    },
    component: SamlAuthorize,
  });
};

export const initSamlReloadModal = () => {
  const el = document.getElementById('js-saml-reload');

  if (!el) return null;

  const { samlProviderId, samlSessionsUrl } = el.dataset;

  return initVueApp({
    el,
    name: 'SamlReloadRoot',
    component: SamlReloadModal,
    props: { samlProviderId: parseInt(samlProviderId, 10), samlSessionsUrl },
  });
};
