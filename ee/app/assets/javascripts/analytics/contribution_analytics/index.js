import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import App from './components/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default (el) => {
  const { fullPath, startDate, endDate, dataSourceClickhouse } = el.dataset;
  return initVueApp({
    el,
    apolloProvider,
    name: 'ContributionAnalyticsRoot',
    component: App,
    props: {
      fullPath,
      startDate,
      endDate,
      dataSourceClickhouse: parseBoolean(dataSourceClickhouse),
    },
  });
};
