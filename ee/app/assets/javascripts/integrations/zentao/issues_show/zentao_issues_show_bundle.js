import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import ZentaoIssuesShowApp from './components/zentao_issues_show_root.vue';

export default function initZentaoIssueShow({ mountPointSelector }) {
  const mountPointEl = document.querySelector(mountPointSelector);

  if (!mountPointEl) {
    return null;
  }

  const { issuesShowPath, issuesListPath } = mountPointEl.dataset;

  return initVueApp({
    el: mountPointEl,
    name: 'ZentaoIssuesShowAppRoot',
    provide: {
      issuesShowPath,
      issuesListPath,
      isClassicSidebar: true,
    },
    component: ZentaoIssuesShowApp,
  });
}
