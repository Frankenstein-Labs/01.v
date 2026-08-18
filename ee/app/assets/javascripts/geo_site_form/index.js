import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import Translate from '~/vue_shared/translate';
import createDefaultClient from '~/lib/graphql';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import GeoSiteFormApp from './components/app.vue';
import createStore from './store';

Vue.use(Translate);
Vue.use(VueApollo);

export default () => {
  const el = document.getElementById('js-geo-site-form');

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const {
    dataset: { selectiveSyncTypes, syncShardsOptions, siteData, sitesPath },
  } = el;

  let site;
  if (siteData) {
    site = JSON.parse(siteData);
    site = convertObjectPropsToCamelCase(site, { deep: true });
  }

  return initVueApp({
    el,
    name: 'GeoSiteFormAppRoot',
    apolloProvider,
    store: createStore(sitesPath),
    component: GeoSiteFormApp,
    props: {
      selectiveSyncTypes: JSON.parse(selectiveSyncTypes),
      syncShardsOptions: JSON.parse(syncShardsOptions),
      site,
    },
  });
};
