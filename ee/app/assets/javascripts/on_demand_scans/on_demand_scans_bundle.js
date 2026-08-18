import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import { createRouter } from './router';
import OnDemandScans from './components/on_demand_scans.vue';
import apolloProvider from './graphql/provider';

export default () => {
  const el = document.querySelector('#js-on-demand-scans');
  if (!el) {
    return null;
  }
  const {
    canEditOnDemandScans,
    projectPath,
    newDastScanPath,
    emptyStateSvgPath,
    projectOnDemandScanCountsEtag,
  } = el.dataset;

  const initialOnDemandScanCounts = JSON.parse(el.dataset.onDemandScanCounts);
  const timezones = JSON.parse(el.dataset.timezones);
  const parsedCanEditOnDemandScans = parseBoolean(canEditOnDemandScans);

  return initVueApp({
    el,
    name: 'OnDemandScansRoot',
    router: createRouter(),
    apolloProvider,
    provide: {
      canEditOnDemandScans: parsedCanEditOnDemandScans,
      projectPath,
      newDastScanPath,
      emptyStateSvgPath,
      projectOnDemandScanCountsEtag,
      timezones,
    },
    component: OnDemandScans,
    props: {
      initialOnDemandScanCounts,
    },
  });
};
