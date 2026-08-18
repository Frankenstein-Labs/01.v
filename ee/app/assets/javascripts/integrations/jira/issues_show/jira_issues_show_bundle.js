import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

import JiraIssuesShowApp from './components/jira_issues_show_root.vue';

export default function initJiraIssueShow({ mountPointSelector }) {
  const mountPointEl = document.querySelector(mountPointSelector);

  if (!mountPointEl) {
    return null;
  }

  const { issuesShowPath, issuesListPath } = mountPointEl.dataset;

  return initVueApp({
    el: mountPointEl,
    name: 'JiraIssuesShowAppRoot',
    provide: {
      issuesShowPath,
      issuesListPath,
      isClassicSidebar: true,
    },
    component: JiraIssuesShowApp,
  });
}
