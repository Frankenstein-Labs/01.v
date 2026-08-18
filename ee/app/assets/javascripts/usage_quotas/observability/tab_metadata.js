import { s__ } from '~/locale';
import { createAsyncTabContentWrapper } from '~/usage_quotas/components/async_tab_content_wrapper';

export const parseProvideData = (element) => {
  return element.dataset.viewModel ? JSON.parse(element.dataset.viewModel) : {};
};

export const getObservabilityTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector('#js-observability-usage-quota-app');

  if (!el) return false;

  const ObservabilityUsageQuotaApp = () => {
    const component = import(
      /* webpackChunkName: 'uq_observability' */ './components/observability_usage_quota_app.vue'
    );
    return createAsyncTabContentWrapper(component);
  };

  const observabilityTabMetadata = {
    title: s__('UsageQuota|Observability'),
    hash: '#observability-usage-quota-tab',
    testid: 'observability-tab',
    featureCategory: 'error_budgets',
    component: {
      name: 'ObservabilityUsageQuotaTab',
      provide: parseProvideData(el),
      render(createElement) {
        return createElement(ObservabilityUsageQuotaApp);
      },
    },
  };

  if (includeEl) {
    observabilityTabMetadata.component.el = el;
  }

  return observabilityTabMetadata;
};
