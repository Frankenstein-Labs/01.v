import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { helpPagePath } from '~/helpers/help_page_helper';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import CloudLicenseShowApp from './components/app.vue';
import initialStore from './store';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export default () => {
  const el = document.getElementById('js-show-subscription-page');

  if (!el) {
    return null;
  }

  const {
    congratulationSvgPath,
    customersPortalUrl,
    freeTrialPath,
    hasActiveLicense,
    licenseRemovePath,
    subscriptionSyncPath,
    licenseUsageFilePath,
    isAdmin,
    settingsAddLicensePath,
    groupsCount,
    projectsCount,
    usersCount,
    purchaseCreditsPath,
  } = el.dataset;
  const connectivityHelpURL = helpPagePath('/administration/license.html', {
    anchor: 'error-cannot-activate-instance-due-to-a-connectivity-issue',
  });

  return initVueApp({
    el,
    store: initialStore({ licenseRemovalPath: licenseRemovePath, subscriptionSyncPath }),
    name: 'CloudLicenseRoot',
    apolloProvider,
    provide: {
      congratulationSvgPath,
      connectivityHelpURL,
      customersPortalUrl,
      freeTrialPath,
      licenseRemovePath,
      subscriptionSyncPath,
      settingsAddLicensePath,
      groupsCount: Number(groupsCount),
      projectsCount: Number(projectsCount),
      usersCount: Number(usersCount),
      purchaseCreditsPath,
    },
    component: CloudLicenseShowApp,
    props: {
      hasActiveLicense: parseBoolean(hasActiveLicense),
      licenseUsageFilePath,
      isAdmin: parseBoolean(isAdmin),
    },
  });
};
