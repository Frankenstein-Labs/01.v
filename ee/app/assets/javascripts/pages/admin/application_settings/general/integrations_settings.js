import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import AllowedIntegrations from './components/allowed_integrations.vue';

export default function initAllowedIntegrations() {
  const el = document.querySelector('.js-allowed-integrations');

  if (!el) {
    return false;
  }

  const { allowAllIntegrations, allowedIntegrations, integrations } = el.dataset;

  return initVueApp({
    el,
    name: 'AllowedIntegrationsRoot',
    component: AllowedIntegrations,
    props: {
      initialAllowAllIntegrations: parseBoolean(allowAllIntegrations),
      initialAllowedIntegrations: JSON.parse(allowedIntegrations),
      integrations: JSON.parse(integrations),
    },
  });
}
