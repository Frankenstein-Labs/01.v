import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { mergeRequestApprovalSettingsMappers } from '../mappers';
import createStore from '../stores';
import approvalSettingsModule from '../stores/modules/approval_settings';
import projectSettingsModule from '../stores/modules/project_settings';
import ProjectSettingsApp from './app.vue';

export default function mountProjectSettingsApprovals(el) {
  if (!el) {
    return null;
  }

  const { coverageCheckHelpPagePath, fullPath, newPolicyPath } = el.dataset;

  const modules = {
    approvals: projectSettingsModule(),
  };

  modules.approvalSettings = approvalSettingsModule(mergeRequestApprovalSettingsMappers);

  const store = createStore(modules, {
    ...el.dataset,
    prefix: 'project-settings',
    allowAllProtectedBranchesOption: true,
    allowMultiRule: parseBoolean(el.dataset.allowMultiRule),
    canEdit: parseBoolean(el.dataset.canEdit),
    canModifyAuthorSettings: parseBoolean(el.dataset.canModifyAuthorSettings),
    canModifyCommiterSettings: parseBoolean(el.dataset.canModifyCommiterSettings),
  });

  Vue.use(GlToast);

  return initVueApp({
    el,
    name: 'ProjectSettingsAppRoot',
    store,
    apolloProvider: new VueApollo({
      defaultClient: createDefaultClient(),
    }),
    provide: {
      coverageCheckHelpPagePath,
      fullPath,
      newPolicyPath,
      canReadSecurityPolicies: parseBoolean(el.dataset.canReadSecurityPolicies),
    },
    component: ProjectSettingsApp,
  });
}
