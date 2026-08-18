import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import DependencyFirewallDashboardApp from './components/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default (el) => {
  if (!el) return null;

  const { fullPath, namespaceType } = el.dataset;

  return new Vue({
    el,
    name: 'DependencyFirewallDashboardRoot',
    apolloProvider,
    render(createElement) {
      return createElement(DependencyFirewallDashboardApp, {
        props: {
          fullPath,
          namespaceType,
        },
      });
    },
  });
};
