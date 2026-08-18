import Vue from 'vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import { getParameterByName } from '~/lib/utils/url_utility';
import Translate from '~/vue_shared/translate';
import GeoSitesApp from './components/app.vue';
import createStore from './store';

Vue.use(Translate);

export const initGeoSites = () => {
  const el = document.getElementById('js-geo-sites');

  if (!el) {
    return false;
  }

  const { newSiteUrl, geoSitesEmptyStateSvg, geoLicenseAllows, manageSubscriptionUrl } = el.dataset;
  const searchFilter = getParameterByName('search') || '';
  let { replicableTypes } = el.dataset;

  replicableTypes = convertObjectPropsToCamelCase(JSON.parse(replicableTypes), { deep: true });

  return initVueApp({
    el,
    name: 'GeoSitesAppRoot',
    store: createStore({ replicableTypes, searchFilter }),
    provide: {
      geoSitesEmptyStateSvg,
      geoLicenseAllows: parseBoolean(geoLicenseAllows),
      manageSubscriptionUrl,
    },
    component: GeoSitesApp,
    props: {
      newSiteUrl,
    },
  });
};
