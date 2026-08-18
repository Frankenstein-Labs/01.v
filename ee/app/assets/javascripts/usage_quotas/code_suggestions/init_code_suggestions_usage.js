import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import { parseBoolean } from '~/lib/utils/common_utils';
import CodeSuggestionsUsage from './components/code_suggestions_usage.vue';

export function initCodeSuggestionsUsage() {
  const el = document.getElementById('js-code-suggestions-page');

  if (!el) {
    return null;
  }

  return initVueApp({
    el,
    name: 'CodeSuggestionsUsage',
    apolloProvider,
    provide: {
      isSaaS: false,
      addDuoProHref: el.dataset.addDuoProSeatsUrl,
      subscriptionName: el.dataset.subscriptionName,
      isBulkAddOnAssignmentEnabled: parseBoolean(el.dataset.isBulkAddOnAssignmentEnabled),
      duoAddOnStartDate: el.dataset.duoAddOnStartDate,
      duoAddOnEndDate: el.dataset.duoAddOnEndDate,
    },
    component: CodeSuggestionsUsage,
  });
}
