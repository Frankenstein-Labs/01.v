import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import RoleCreate from './components/manage_role/role_create.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initCreateMemberRoleApp = () => {
  const el = document.querySelector('#js-create-member-role');

  if (!el) {
    return null;
  }

  const { groupFullPath, listPagePath, isAdminRole } = el.dataset;

  return initVueApp({
    el,
    name: 'CreateRoleRoot',
    apolloProvider,
    provide: { isAdminRole: parseBoolean(isAdminRole) },
    component: RoleCreate,
    props: { groupFullPath, listPagePath },
  });
};
