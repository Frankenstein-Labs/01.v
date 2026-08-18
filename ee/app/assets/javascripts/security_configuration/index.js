import Vue from 'vue';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import SecurityConfigurationBreadcrumb from './components/security_configuration_breadcrumb.vue';
import { routes } from './routes';

Vue.use(VueApollo);
Vue.use(VueRouter);

export const initSecurityConfiguration = (el) => {
  if (!el) {
    return null;
  }

  const {
    groupFullPath,
    groupId,
    groupName,
    namespaceId,
    securityInventoryPath,
    canReadAttributes,
    canManageAttributes,
    canReadScanProfiles,
    canApplyProfiles,
  } = el.dataset;

  const router = new VueRouter({ routes });

  injectVueAppBreadcrumbs(router, SecurityConfigurationBreadcrumb);

  return new Vue({
    el,
    name: 'SecurityConfigurationRoot',
    router,
    apolloProvider: new VueApollo({
      defaultClient: createDefaultClient(),
    }),
    provide: {
      groupFullPath,
      groupId,
      groupName,
      namespaceId,
      securityInventoryPath,
      canReadAttributes: parseBoolean(canReadAttributes),
      canManageAttributes: parseBoolean(canManageAttributes),
      canReadScanProfiles: parseBoolean(canReadScanProfiles),
      canApplyProfiles: parseBoolean(canApplyProfiles),
    },
    render(createElement) {
      return createElement('router-view');
    },
  });
};
