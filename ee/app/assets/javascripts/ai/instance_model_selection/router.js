import Vue from 'vue';
import VueRouter from 'vue-router';
import NewSelfHostedModel from './self_hosted_models/components/new_self_hosted_model.vue';
import EditSelfHostedModel from './self_hosted_models/components/edit_self_hosted_model.vue';
import InstanceModelSelectionRootApp from './app.vue';
import { INSTANCE_MODEL_SELECTION_TABS, INSTANCE_MODEL_SELECTION_ROUTE_NAMES } from './constants';

Vue.use(VueRouter);

export default function createRouter(basePath) {
  const router = new VueRouter({
    mode: 'history',
    base: basePath,
    routes: [
      {
        name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.INDEX,
        path: '/',
        component: InstanceModelSelectionRootApp,
      },
      {
        name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.NEW,
        path: '/models/new',
        component: NewSelfHostedModel,
      },
      {
        name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.EDIT,
        path: '/models/:id/edit',
        component: EditSelfHostedModel,
        props: ({ params: { id } }) => {
          return { modelId: Number(id) };
        },
      },
      {
        name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.FEATURES,
        path: '/features',
        component: InstanceModelSelectionRootApp,
        props: () => ({ tabId: INSTANCE_MODEL_SELECTION_TABS.AI_FEATURE_SETTINGS }),
      },
      {
        name: INSTANCE_MODEL_SELECTION_ROUTE_NAMES.MODELS,
        path: '/models',
        component: InstanceModelSelectionRootApp,
        props: () => ({ tabId: INSTANCE_MODEL_SELECTION_TABS.SELF_HOSTED_MODELS }),
      },
      {
        path: '*',
        redirect: '/',
      },
    ],
  });

  return router;
}
