import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { addShortcutsExtension } from '~/behaviors/shortcuts';
import ShortcutsTestCase from 'ee/behaviors/shortcuts/shortcuts_test_case';

import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';

import TestCaseShowApp from './components/test_case_show_root.vue';

Vue.use(VueApollo);

export default function initTestCaseShow({ mountPointSelector }) {
  addShortcutsExtension(ShortcutsTestCase);
  const el = document.querySelector(mountPointSelector);

  if (!el) {
    return null;
  }

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const sidebarOptions = JSON.parse(el.dataset.sidebarOptions);

  return initVueApp({
    el,
    name: 'TestCaseRoot',
    apolloProvider,
    provide: {
      ...el.dataset,
      projectsFetchPath: sidebarOptions.projectsAutocompleteEndpoint,
      canEditTestCase: parseBoolean(el.dataset.canEditTestCase),
      canUpdate: parseBoolean(el.dataset.canEditTestCase),
      allowLabelCreate: true,
      allowLabelEdit: true,
      allowScopedLabels: true,
      isClassicSidebar: true,
      lockVersion: parseInt(el.dataset.lockVersion, 10),
    },
    component: TestCaseShowApp,
  });
}
