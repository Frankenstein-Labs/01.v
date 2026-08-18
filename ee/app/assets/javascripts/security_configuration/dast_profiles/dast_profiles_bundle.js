import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import DastProfiles from './components/dast_profiles.vue';
import apolloProvider from './graphql/provider';

export default () => {
  const el = document.querySelector('.js-dast-profiles');

  if (!el) {
    return undefined;
  }

  const {
    dataset: { newDastScannerProfilePath, newDastSiteProfilePath, projectFullPath, timezones },
  } = el;

  const props = {
    createNewProfilePaths: {
      scannerProfile: newDastScannerProfilePath,
      siteProfile: newDastSiteProfilePath,
    },
    projectFullPath,
  };

  return initVueApp({
    el,
    name: 'DastProfilesRoot',
    apolloProvider,
    provide: {
      timezones: JSON.parse(timezones),
    },
    component: DastProfiles,
    props,
  });
};
