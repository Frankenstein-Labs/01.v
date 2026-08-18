import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import RoleEdit from './components/manage_role/role_edit.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initEditMemberRoleApp = () => {
  const el = document.querySelector('#js-edit-member-role');

  if (!el) {
    return null;
  }

  const { listPagePath, roleId, isAdminRole } = el.dataset;

  return initVueApp({
    el,
    name: 'EditRoleRoot',
    apolloProvider,
    provide: { isAdminRole: parseBoolean(isAdminRole) },
    component: RoleEdit,
    props: { roleId: Number(roleId), listPagePath },
  });
};
