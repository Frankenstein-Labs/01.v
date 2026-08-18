import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import GroupLinkRoleSelector from './components/group_link_role_selector.vue';

export default () => {
  const el = document.querySelector('.js-group-link-role-selector');

  if (!el) {
    return null;
  }

  const {
    groupLinkRoleSelectorData = {},
    baseAccessLevelInputName,
    memberRoleIdInputName,
  } = el.dataset;

  const { standardRoles, customRoles = [] } = convertObjectPropsToCamelCase(
    JSON.parse(groupLinkRoleSelectorData),
    { deep: true },
  );

  return initVueApp({
    el,
    name: 'GroupLinkRoleSelectorRoot',
    provide: {
      standardRoles,
      customRoles,
    },
    component: GroupLinkRoleSelector,
    props: {
      baseAccessLevelInputName,
      memberRoleIdInputName,
    },
  });
};
