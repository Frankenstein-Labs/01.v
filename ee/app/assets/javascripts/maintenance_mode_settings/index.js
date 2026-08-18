import Vue from 'vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import Translate from '~/vue_shared/translate';
import MaintenanceModeSettingsApp from './components/app.vue';

Vue.use(Translate);

export const initMaintenanceModeSettings = () => {
  const el = document.getElementById('js-maintenance-mode-settings');

  if (!el) {
    return false;
  }

  const { maintenanceEnabled, bannerMessage: initialBannerMessage } = el.dataset;
  const initialMaintenanceEnabled = parseBoolean(maintenanceEnabled);

  return initVueApp({
    el,
    name: 'MaintenanceModeSettingsAppRoot',
    component: MaintenanceModeSettingsApp,
    props: {
      initialMaintenanceEnabled,
      initialBannerMessage,
    },
  });
};
