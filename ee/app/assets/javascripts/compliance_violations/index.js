import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import ZenMode from '~/zen_mode';
import ViolationDetailsApp from './components/compliance_violation_details_app.vue';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export const initDetailsApp = () => {
  const el = document.querySelector('#js-project-violation-details');

  if (!el) {
    return false;
  }

  // Initialize ZenMode for fullscreen markdown editor functionality
  new ZenMode(); // eslint-disable-line no-new

  const { violationId, complianceCenterPath, uploadsPath, markdownPreviewPath } = el.dataset;

  return initVueApp({
    el,
    name: 'ComplianceViolationDetailsRoot',
    apolloProvider,
    provide: {
      uploadsPath,
      markdownPreviewPath,
    },
    component: ViolationDetailsApp,
    props: {
      violationId,
      complianceCenterPath,
    },
  });
};
