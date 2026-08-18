import Vue from 'vue';
import { GlToast } from '@gitlab/ui';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import { mergeRequestApprovalSettingsMappers } from '../mappers';
import createStore from '../stores';
import approvalSettingsModule from '../stores/modules/approval_settings';
import GroupSettingsApp from './app.vue';

const mountGroupApprovalSettings = (el) => {
  if (!el) {
    return null;
  }

  const { defaultExpanded, fullPath, approvalSettingsPath } = el.dataset;
  const store = createStore({
    approvalSettings: approvalSettingsModule(mergeRequestApprovalSettingsMappers),
  });

  Vue.use(GlToast);

  return initVueApp({
    el,
    name: 'GroupSettingsAppRoot',
    store,
    provide: {
      fullPath,
      isGroup: true,
    },
    component: GroupSettingsApp,
    props: {
      defaultExpanded: parseBoolean(defaultExpanded),
      approvalSettingsPath,
    },
  });
};

export { mountGroupApprovalSettings };
