import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import CentralizedSecurityPolicyManagement from './components/centralized_security_policy_management.vue';

export const initCentralizedSecurityPolicyManagement = () => {
  const el = document.getElementById('js-centralized_security_policy_management');

  if (!el) return false;

  const {
    centralizedSecurityPolicyGroupId,
    centralizedSecurityPolicyGroupLocked,
    formId,
    newGroupPath,
  } = el.dataset;

  return initVueApp({
    apolloProvider,
    el,
    name: 'CentralizedSecurityPolicyManagementRoot',
    component: CentralizedSecurityPolicyManagement,
    props: {
      centralizedSecurityPolicyGroupLocked: parseBoolean(centralizedSecurityPolicyGroupLocked),
      formId,
      initialSelectedGroupId: parseInt(centralizedSecurityPolicyGroupId, 10),
      newGroupPath,
    },
  });
};
