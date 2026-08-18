import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import SecretsManagerInstanceEnrollmentToggle from './components/secrets_manager_instance_enrollment_toggle.vue';

Vue.use(GlToast);
Vue.use(VueApollo);

export const initSecretsManagerInstanceEnrollment = () => {
  const el = document.getElementById('js-secrets-manager-instance-enrollment');

  if (!el) return false;

  const { topLevelGroupFullPath } = el.dataset;

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return initVueApp({
    el,
    name: 'SecretsManagerInstanceEnrollmentRoot',
    apolloProvider,
    component: SecretsManagerInstanceEnrollmentToggle,
    props: {
      topLevelGroupFullPath: topLevelGroupFullPath || '',
    },
  });
};
