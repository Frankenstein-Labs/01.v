import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import SamlMembershipRoleSelector from './components/saml_membership_role_selector.vue';

export default () => {
  const el = document.querySelector('.js-saml-membership-role-selector');

  if (!el) {
    return null;
  }

  const { samlMembershipRoleSelectorData } = el.dataset;
  const {
    standardRoles,
    currentStandardRole,
    customRoles = [],
    currentCustomRoleId,
  } = convertObjectPropsToCamelCase(JSON.parse(samlMembershipRoleSelectorData), { deep: true });

  return initVueApp({
    el,
    name: 'SamlMembershipRoleSelectorRoot',
    provide: {
      standardRoles,
      currentStandardRole,
      customRoles,
      currentCustomRoleId,
    },
    component: SamlMembershipRoleSelector,
  });
};
