import { __ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import { createAsyncTabContentWrapper } from '~/usage_quotas/components/async_tab_content_wrapper';
import apolloProvider from '../shared/provider';

export const parseProvideData = (el) => {
  const {
    fullPath,
    deploymentsLimit,
    deploymentsCount,
    projectDeploymentsCount,
    deploymentsByProject,
    domain,
    usesNamespaceDomain,
  } = el.dataset;

  return {
    fullPath,
    deploymentsLimit: parseInt(deploymentsLimit, 10),
    deploymentsCount: parseInt(deploymentsCount, 10),
    projectDeploymentsCount: parseInt(projectDeploymentsCount, 10),
    deploymentsByProject: deploymentsByProject ? JSON.parse(deploymentsByProject) : [],
    domain,
    usesNamespaceDomain: parseBoolean(usesNamespaceDomain),
  };
};

export const getPagesTabMetadata = ({ viewType } = {}) => {
  const el = document.querySelector('#js-pages-deployments-app');

  if (!el) return false;

  const PagesDeploymentsApp = () => {
    const component = import(/* webpackChunkName: 'uq_pages' */ './components/app.vue');
    return createAsyncTabContentWrapper(component);
  };

  return {
    title: __('Pages'),
    hash: '#pages-deployments-usage-tab',
    testid: 'pages-tab',
    featureCategory: 'pages',
    component: {
      name: 'PagesDeploymentsTab',
      apolloProvider,
      provide: {
        viewType,
        ...parseProvideData(el),
      },
      render(createElement) {
        return createElement(PagesDeploymentsApp);
      },
    },
  };
};
