import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { extractFilterQueryParameters } from '~/analytics/shared/utils';
import CodeAnalyticsApp from './components/app.vue';
import store from './store';

export default () => {
  const container = document.getElementById('js-code-review-analytics');
  const {
    projectId,
    projectPath,
    newMergeRequestUrl,
    emptyStateSvgPath,
    milestonePath,
    labelsPath,
  } = container.dataset;
  if (!container) return;

  store.dispatch('filters/setEndpoints', {
    milestonesEndpoint: milestonePath,
    labelsEndpoint: labelsPath,
    projectEndpoint: projectPath,
  });

  const { selectedMilestone, selectedLabelList } = extractFilterQueryParameters(
    window.location.search,
  );
  store.dispatch('filters/initialize', { selectedMilestone, selectedLabelList });

  initVueApp({
    el: container,
    name: 'CodeAnalyticsAppRoot',
    store,
    component: CodeAnalyticsApp,
    props: {
      projectId: Number(projectId),
      projectPath,
      newMergeRequestUrl,
      emptyStateSvgPath,
    },
  });
};
