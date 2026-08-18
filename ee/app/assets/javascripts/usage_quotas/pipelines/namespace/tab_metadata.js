import { __ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import { isNumeric } from '~/lib/utils/number_utils';
import { createAsyncTabContentWrapper } from '~/usage_quotas/components/async_tab_content_wrapper';

export const parseProvideData = (el) => {
  const {
    pageSize,
    namespaceId,
    namespaceActualPlanName,
    userNamespace,
    ciMinutesAnyProjectEnabled,
    ciMinutesDisplayMinutesAvailableData,
    ciMinutesLastResetDate,
    ciMinutesMonthlyMinutesLimit,
    ciMinutesMonthlyMinutesUsed,
    ciMinutesMonthlyMinutesUsedPercentage,
    ciMinutesPurchasedMinutesLimit,
    ciMinutesPurchasedMinutesUsed,
    ciMinutesPurchasedMinutesUsedPercentage,
    buyAdditionalMinutesPath,
    buyAdditionalMinutesTarget,
  } = el.dataset;

  return {
    pageSize: Number(pageSize),
    namespaceId: parseInt(namespaceId, 10),
    namespaceActualPlanName,
    userNamespace: parseBoolean(userNamespace),
    ciMinutesAnyProjectEnabled: parseBoolean(ciMinutesAnyProjectEnabled),
    ciMinutesDisplayMinutesAvailableData: parseBoolean(ciMinutesDisplayMinutesAvailableData),
    ciMinutesLastResetDate,
    ciMinutesMonthlyMinutesUsed: parseInt(ciMinutesMonthlyMinutesUsed, 10),
    ciMinutesPurchasedMinutesUsed: parseInt(ciMinutesPurchasedMinutesUsed, 10),
    ciMinutesMonthlyMinutesUsedPercentage: parseInt(ciMinutesMonthlyMinutesUsedPercentage, 10),
    ciMinutesPurchasedMinutesUsedPercentage: parseInt(ciMinutesPurchasedMinutesUsedPercentage, 10),
    // Limit could be a number or a string (e.g. `Unlimited`) so we parseInt these conditionally
    ciMinutesMonthlyMinutesLimit: isNumeric(ciMinutesMonthlyMinutesLimit)
      ? parseInt(ciMinutesMonthlyMinutesLimit, 10)
      : ciMinutesMonthlyMinutesLimit,
    ciMinutesPurchasedMinutesLimit: isNumeric(ciMinutesPurchasedMinutesLimit)
      ? parseInt(ciMinutesPurchasedMinutesLimit, 10)
      : ciMinutesPurchasedMinutesLimit,
    buyAdditionalMinutesPath,
    buyAdditionalMinutesTarget,
  };
};

export const getPipelineTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector('#js-pipeline-usage-app');

  if (!el) return false;

  const PipelineUsageApp = () => {
    const component = import(/* webpackChunkName: 'uq_pipelines' */ './components/app.vue');
    return createAsyncTabContentWrapper(component);
  };

  const pipelineTabMetadata = {
    title: __('Pipelines'),
    hash: '#pipelines-quota-tab',
    testid: 'pipelines-tab',
    featureCategory: 'continuous_integration',
    component: {
      name: 'PipelineUsageTab',
      provide: parseProvideData(el),
      apolloProvider,
      render(createElement) {
        return createElement(PipelineUsageApp);
      },
    },
  };

  if (includeEl) {
    pipelineTabMetadata.component.el = el;
  }

  return pipelineTabMetadata;
};
