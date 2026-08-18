import Vue from 'vue';
import PipelineAccountVerificationAlert from 'ee/vue_shared/components/pipeline_account_verification_alert.vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import { s__ } from '~/locale';

export function initDuoAgentsPlatformVerificationAlert() {
  const el = document.querySelector('.js-duo-agents-platform-verification-alert');

  if (!el) {
    return null;
  }

  return new Vue({
    el,
    name: 'DuoAgentsPlatformVerificationAlertRoot',
    provide: {
      identityVerificationRequired: parseBoolean(el.dataset.identityVerificationRequired),
      identityVerificationPath: el.dataset.identityVerificationPath,
    },
    render(createElement) {
      return createElement(PipelineAccountVerificationAlert, {
        props: {
          title: s__(
            'IdentityVerification|Before you can use GitLab Duo Agent Platform, we need to verify your account.',
          ),
          // The alert replaces the page content, so it must not be dismissible
          // (dismissing would leave a blank page).
          dismissible: false,
        },
        class: 'gl-mt-3',
      });
    },
  });
}
