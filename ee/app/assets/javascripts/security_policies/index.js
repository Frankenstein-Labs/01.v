import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import App from './components/app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default (el, namespaceType) => {
  if (!el) return null;

  const {
    assignedPolicyProject,
    disableSecurityPolicyProject,
    disableScanPolicyUpdate,
    namespacePath,
    newPolicyPath,
    rootNamespacePath,
  } = el.dataset;

  let parsedAssignedPolicyProject;
  try {
    parsedAssignedPolicyProject = convertObjectPropsToCamelCase(JSON.parse(assignedPolicyProject));
  } catch {
    parsedAssignedPolicyProject = DEFAULT_ASSIGNED_POLICY_PROJECT;
  }

  return initVueApp({
    apolloProvider,
    el,
    name: 'SecurityPoliciesV2AppRoot',
    provide: {
      assignedPolicyProject: parsedAssignedPolicyProject,
      disableSecurityPolicyProject: parseBoolean(disableSecurityPolicyProject),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      namespacePath,
      namespaceType,
      newPolicyPath,
      rootNamespacePath,
    },
    component: App,
  });
};
