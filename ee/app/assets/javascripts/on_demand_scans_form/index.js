import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import { parseBoolean } from '~/lib/utils/common_utils';
import OnDemandScansForm from './components/on_demand_scans_form.vue';

export default () => {
  const el = document.querySelector('#js-on-demand-scans-form');
  if (!el) {
    return null;
  }

  const {
    canEditRunnerTags,
    projectPath,
    defaultBranch,
    onDemandScansPath,
    scannerProfilesLibraryPath,
    siteProfilesLibraryPath,
  } = el.dataset;
  const dastScan = el.dataset.dastScan ? JSON.parse(el.dataset.dastScan) : null;
  const timezones = JSON.parse(el.dataset.timezones);
  const canEditRunnerTagsParsed = parseBoolean(canEditRunnerTags);
  const additionalVariableOptions = JSON.parse(el.dataset.additionalVariableOptions);

  return initVueApp({
    el,
    name: 'OnDemandScansFormRoot',
    apolloProvider,
    provide: {
      canEditRunnerTags: canEditRunnerTagsParsed,
      projectPath,
      onDemandScansPath,
      scannerProfilesLibraryPath,
      siteProfilesLibraryPath,
      timezones,
      additionalVariableOptions,
    },
    component: OnDemandScansForm,
    props: {
      defaultBranch,
      dastScan,
    },
  });
};
