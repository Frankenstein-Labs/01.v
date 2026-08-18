import { defaultDataIdFromObject } from '@apollo/client/core';
import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import EscalationPoliciesWrapper from './components/escalation_policies_wrapper.vue';

Vue.use(GlToast);
Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: {
        dataIdFromObject: (object) => {
          // eslint-disable-next-line no-underscore-dangle
          if (object.__typename === 'IncidentManagementOncallSchedule') {
            return object.iid;
          }
          return defaultDataIdFromObject(object);
        },
      },
    },
  ),
});

export default () => {
  const el = document.querySelector('.js-escalation-policies');

  if (!el) return null;

  const {
    emptyEscalationPoliciesSvgPath,
    projectPath = '',
    userCanCreateEscalationPolicy,
    accessLevelDescriptionPath,
  } = el.dataset;

  return initVueApp({
    el,
    name: 'EscalationPoliciesWrapperRoot',
    apolloProvider,
    provide: {
      projectPath,
      emptyEscalationPoliciesSvgPath,
      userCanCreateEscalationPolicy: parseBoolean(userCanCreateEscalationPolicy),
      accessLevelDescriptionPath,
    },
    component: EscalationPoliciesWrapper,
  });
};
