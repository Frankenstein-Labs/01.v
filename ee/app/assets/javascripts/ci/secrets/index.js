import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from './context_config';
import createRouter from './router';
import SecretsApp from './components/secrets_app.vue';
import SecretsBreadcrumbs from './components/secrets_breadcrumbs.vue';
import { ENTITY_GROUP, ENTITY_PROJECT } from './constants';

Vue.use(VueApollo);
Vue.use(GlToast);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

const isSaas = gon.dot_com;

const initSecretsApp = (el, provide) => {
  const { basePath, enrollmentSettingsPath, managePermissionsPath, topLevelGroupFullPath } =
    el.dataset;

  const extendedProvided = {
    ...provide,
    enrollmentSettingsPath,
    isSaas: parseBoolean(isSaas),
    managePermissionsPath: managePermissionsPath || '',
    topLevelGroupFullPath: topLevelGroupFullPath || '',
  };

  const router = createRouter(basePath);

  if (window.location.href.includes(basePath)) {
    injectVueAppBreadcrumbs(router, SecretsBreadcrumbs);
  }

  return initVueApp({
    el,
    router,
    name: 'SecretsRoot',
    provide: extendedProvided,
    apolloProvider,
    component: SecretsApp,
  });
};

export const initGroupSecretsApp = () => {
  const el = document.querySelector('#js-group-secrets-manager');

  if (!el) {
    return false;
  }

  const { groupPath } = el.dataset;

  return initSecretsApp(el, {
    contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[ENTITY_GROUP],
    fullPath: groupPath,
  });
};

export const initProjectSecretsApp = () => {
  const el = document.querySelector('#js-project-secrets-manager');

  if (!el) {
    return false;
  }

  const { projectPath } = el.dataset;

  return initSecretsApp(el, {
    contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[ENTITY_PROJECT],
    fullPath: projectPath,
  });
};
