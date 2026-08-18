import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import DastConfigurationApp from './components/app.vue';

export default function init() {
  const el = document.querySelector('.js-dast-configuration');

  if (!el) {
    return undefined;
  }

  const {
    securityConfigurationPath,
    fullPath,
    gitlabCiYamlEditPath,
    siteProfilesLibraryPath,
    scannerProfilesLibraryPath,
    newScannerProfilePath,
    newSiteProfilePath,
    pipelineCreatedAt,
    pipelineId,
    pipelinePath,
    scannerProfile,
    siteProfile,
  } = el.dataset;

  const dastEnabled = 'dastEnabled' in el.dataset;

  return initVueApp({
    el,
    name: 'DastConfigurationAppRoot',
    apolloProvider,
    provide: {
      securityConfigurationPath,
      projectPath: fullPath,
      gitlabCiYamlEditPath,
      siteProfilesLibraryPath,
      scannerProfilesLibraryPath,
      newScannerProfilePath,
      newSiteProfilePath,
      dastEnabled,
      pipelineCreatedAt,
      pipelineId,
      pipelinePath,
      scannerProfile,
      siteProfile,
    },
    component: DastConfigurationApp,
  });
}
