import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

export const initMergeRequestMergeChecksApp = async () => {
  const el = document.querySelector('.js-merge-request-merge-checks');

  if (!el) {
    return false;
  }

  const { default: MergeChecksApp } = await import(
    /* webpackChunkName: 'mergeChecksApp' */ './components/merge_checks_app.vue'
  );
  const { sourceType, settings, parentGroupName } = el.dataset;

  const { allowMergeOnSkippedPipeline, onlyAllowMergeIfAllResolved, pipelineMustSucceed } =
    convertObjectPropsToCamelCase(JSON.parse(settings));

  return initVueApp({
    el,
    name: 'MergeChecksRoot',
    provide: {
      parentGroupName,
      sourceType,
      allowMergeOnSkippedPipeline,
      onlyAllowMergeIfAllResolved,
      pipelineMustSucceed,
    },
    component: MergeChecksApp,
  });
};
