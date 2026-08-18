import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import ComplianceInfo from './components/compliance_info.vue';

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

export function initComplianceInfo() {
  const el = document.getElementById('js-compliance-info');

  if (!el) {
    return null;
  }

  const { projectPath, complianceCenterPath, canViewDashboard } = el.dataset;

  return initVueApp({
    el,
    name: 'ComplianceInfoRoot',
    apolloProvider,
    component: ComplianceInfo,
    props: {
      projectPath,
      complianceCenterPath,
      canViewDashboard,
    },
  });
}
