import Vue from 'vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { observable } from '~/lib/utils/observable';
import Translate from '~/vue_shared/translate';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import RegistryBreadcrumb from '~/packages_and_registries/shared/components/registry_breadcrumb.vue';
import { apolloProvider } from 'ee_component/packages_and_registries/google_artifact_registry/graphql/index';
import GoogleArtifactRegistryIndexPage from 'ee_component/packages_and_registries/google_artifact_registry/pages/index.vue';
import createRouter from 'ee_component/packages_and_registries/google_artifact_registry/router';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-google-artifact-registry');
  const { endpoint, fullPath, settingsPath } = el.dataset;

  // This is a mini state to help the breadcrumb have the correct name in the details page
  const breadCrumbState = observable('google_artifact_registry_breadcrumb', {
    name: '',
    updateName(value) {
      this.name = value;
    },
  });

  const router = createRouter(endpoint, breadCrumbState);

  const attachMainComponent = () =>
    initVueApp({
      el,
      name: 'GoogleArtifactRegistryApp',
      apolloProvider,
      router,
      provide: {
        fullPath,
        settingsPath,
        breadCrumbState,
      },
      component: GoogleArtifactRegistryIndexPage,
    });

  return {
    attachBreadcrumb: () => injectVueAppBreadcrumbs(router, RegistryBreadcrumb, apolloProvider),
    attachMainComponent,
  };
};
