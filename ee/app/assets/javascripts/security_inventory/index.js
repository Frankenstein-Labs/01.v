import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from './graphql/provider';
import App from './components/app.vue';

export default () => {
  const el = document.querySelector('#js-group-security-inventory');
  if (!el) {
    return null;
  }

  const {
    groupFullPath,
    groupId,
    canManageAttributes,
    canReadAttributes,
    canApplyProfiles,
    groupManageAttributesPath,
    newProjectPath,
  } = el.dataset;

  return initVueApp({
    el,
    apolloProvider,
    provide: {
      groupFullPath,
      groupId,
      canManageAttributes: parseBoolean(canManageAttributes),
      canReadAttributes: parseBoolean(canReadAttributes),
      canApplyProfiles: parseBoolean(canApplyProfiles),
      groupManageAttributesPath,
      newProjectPath,
    },
    component: App,
  });
};
