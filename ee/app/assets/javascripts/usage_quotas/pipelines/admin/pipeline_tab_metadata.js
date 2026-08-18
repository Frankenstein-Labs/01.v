import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { __ } from '~/locale';
import createApolloClient from '~/lib/graphql';
import { PIPELINES_TAB_METADATA_EL_SELECTOR } from './constants';
import PipelineUsageApp from './pipelines_admin_app.vue';

export const getPipelineTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector(PIPELINES_TAB_METADATA_EL_SELECTOR);
  const apolloProvider = new VueApollo({ defaultClient: createApolloClient() });

  if (!el) return false;

  Vue.use(VueApollo);

  const pipelineTabMetadata = {
    title: __('Pipelines'),
    hash: '#pipelines-quota-tab',
    testid: 'pipelines-tab',
    component: {
      name: 'PipelineUsageTab',
      apolloProvider,
      render(createElement) {
        return createElement(PipelineUsageApp);
      },
    },
  };

  if (includeEl) {
    pipelineTabMetadata.component.el = el;
  }

  return pipelineTabMetadata;
};
