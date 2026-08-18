import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import { parseProvideData } from 'ee/usage_quotas/code_suggestions/utils';

export function initGitLabDuoUsageSettings() {
  const el = document.getElementById('js-gitlab-duo-usage-settings');

  if (!el) return false;

  return initVueApp({
    el,
    name: 'GitLabDuoUsageSettings',
    apolloProvider,
    provide: parseProvideData(el),
    component: CodeSuggestionsUsage,
  });
}
