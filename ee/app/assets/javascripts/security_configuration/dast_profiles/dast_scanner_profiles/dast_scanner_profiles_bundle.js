import { returnToPreviousPageFactory } from 'ee/security_configuration/dast_profiles/redirect';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import DastScannerProfileForm from './components/dast_scanner_profile_form.vue';

export default () => {
  const el = document.querySelector('.js-dast-scanner-profile-form');
  if (!el) {
    return false;
  }

  const { projectFullPath, profilesLibraryPath, onDemandScanFormPath, dastConfigurationPath } =
    el.dataset;

  const props = { projectFullPath };

  if (el.dataset.scannerProfile) {
    props.profile = convertObjectPropsToCamelCase(JSON.parse(el.dataset.scannerProfile));
  }

  const factoryParams = {
    allowedPaths: [onDemandScanFormPath, dastConfigurationPath],
    profilesLibraryPath,
    urlParamKey: 'scanner_profile_id',
  };

  return initVueApp({
    el,
    name: 'DastScannerProfileFormRoot',
    apolloProvider,
    component: DastScannerProfileForm,
    props,
    events: {
      success: returnToPreviousPageFactory(factoryParams),
      cancel: returnToPreviousPageFactory(factoryParams),
    },
  });
};
