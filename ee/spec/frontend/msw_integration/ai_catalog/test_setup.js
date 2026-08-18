import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlToast } from '@gitlab/ui';
import createDefaultClient from '~/lib/graphql';
import { assignRouter, fullMount } from 'ee_jest/msw_integration/test_helpers';
import { createRouter } from 'ee/ai/catalog/router';
import { NAMESPACE_EXPLORE, NAMESPACE_PROJECT } from 'ee/ai/catalog/constants';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

Vue.use(VueApollo);
Vue.use(GlToast);

// GlToast uses BToast, which doesn't render into the DOM under jsdom.
// We replace $toast.show with a DOM-rendering mock so tests can assert
// with getText(document.body), the same pattern used everywhere else.
// Remove this block when @gitlab/ui ships a jsdom-compatible toast.
const TOAST_CONTAINER_ID = 'msw-toast-container';

function getToastContainer() {
  let container = document.getElementById(TOAST_CONTAINER_ID);
  if (!container) {
    container = document.createElement('div');
    container.id = TOAST_CONTAINER_ID;
    document.body.appendChild(container);
  }
  return container;
}

let originalToast;

beforeEach(() => {
  originalToast = Vue.prototype.$toast;
  Vue.prototype.$toast = {
    show: jest.fn((message) => {
      const el = document.createElement('div');
      el.className = 'gl-toast';
      el.textContent = message;
      getToastContainer().appendChild(el);
    }),
  };
});

afterEach(() => {
  Vue.prototype.$toast = originalToast;
  const container = document.getElementById(TOAST_CONTAINER_ID);
  if (container) {
    container.remove();
  }
});

beforeEach(() => {
  window.gon = {
    ...window.gon,
    features: { ...window.gon?.features },
  };
});

// Mirrors ee/app/assets/javascripts/ai/catalog/index.js
export const EXPLORE_PROVIDE = {
  namespace: NAMESPACE_EXPLORE,
  isGlobalNamespace: true,
  isProjectNamespace: false,
  isGroupNamespace: false,
  aiImpactDashboardEnabled: false,
  instanceBetaFeaturesEnabled: false,
  showLegalDisclaimer: false,
};

// Mirrors ee/app/assets/javascripts/ai/duo_agents_platform/index.js
// + namespace/project/index.js
export const PROJECT_PROVIDE = {
  namespace: NAMESPACE_PROJECT,
  isGlobalNamespace: false,
  isProjectNamespace: true,
  isGroupNamespace: false,
  projectId: '1',
  projectPath: 'gitlab-org/gitlab',
  rootGroupId: null,
  aiImpactDashboardEnabled: false,
  aiImpactDashboardPath: null,
  instanceBetaFeaturesEnabled: false,
};

const createAiCatalogRouter = () => createRouter('/');

export function mountAiCatalogComponent({
  component,
  routePath,
  apolloProvider,
  provide,
  propsData,
}) {
  if (!provide) {
    throw new Error(
      'mountAiCatalogComponent requires a `provide` argument. Use PROJECT_PROVIDE or EXPLORE_PROVIDE.',
    );
  }

  const router = assignRouter(createAiCatalogRouter, { routerPath: routePath });

  return fullMount(component, {
    router,
    apolloProvider,
    provide,
    propsData,
  });
}

export function createApolloProvider() {
  return new VueApollo({ defaultClient: createDefaultClient() });
}
