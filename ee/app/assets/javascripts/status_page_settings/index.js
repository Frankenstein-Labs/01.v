import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import StatusPageSettings from './components/settings_form.vue';
import createStore from './store';

export default () => {
  const el = document.querySelector('.js-status-page-settings');

  if (!el) {
    return null;
  }

  return initVueApp({
    el,
    name: 'StatusPageSettingsRoot',
    store: createStore(el.dataset),
    component: StatusPageSettings,
  });
};
