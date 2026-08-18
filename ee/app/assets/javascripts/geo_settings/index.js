import Vue from 'vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import Translate from '~/vue_shared/translate';
import GeoSettingsApp from './components/app.vue';
import createStore from './store';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-geo-settings-form');

  const {
    dataset: { sitesPath },
  } = el;

  return initVueApp({
    el,
    name: 'GeoSettingsAppRoot',
    store: createStore(sitesPath),
    component: GeoSettingsApp,
  });
};
