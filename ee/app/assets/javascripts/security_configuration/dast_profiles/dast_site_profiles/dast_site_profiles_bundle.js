import { returnToPreviousPageFactory } from 'ee/security_configuration/dast_profiles/redirect';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import DastSiteProfileForm from './components/dast_site_profile_form.vue';

export default () => {
  const el = document.querySelector('.js-dast-site-profile-form');
  if (!el) {
    return;
  }

  const { projectFullPath, profilesLibraryPath, onDemandScanFormPath, dastConfigurationPath } =
    el.dataset;

  const props = { projectFullPath };

  if (el.dataset.siteProfile) {
    props.profile = convertObjectPropsToCamelCase(JSON.parse(el.dataset.siteProfile));
  }

  const factoryParams = {
    allowedPaths: [onDemandScanFormPath, dastConfigurationPath],
    profilesLibraryPath,
    urlParamKey: 'site_profile_id',
  };

  initVueApp({
    el,
    name: 'DastSiteProfileFormRoot',
    provide: {
      additionalVariableOptions: JSON.parse(el.dataset.additionalVariableOptions),
    },
    apolloProvider,
    component: DastSiteProfileForm,
    props,
    events: {
      success: returnToPreviousPageFactory(factoryParams),
      cancel: returnToPreviousPageFactory(factoryParams),
    },
  });
};
