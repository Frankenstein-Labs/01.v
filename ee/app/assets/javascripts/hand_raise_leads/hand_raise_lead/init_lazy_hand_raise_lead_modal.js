import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import handRaiseLeadEventHub from './event_hub';

export function initLazyHandRaiseLeadModal(el) {
  const { handRaiseLeadUser: user, handRaiseLeadSubmitPath: submitPath } = el.dataset;
  const isHandRaiseLeadAvailable = Boolean(user && submitPath);

  if (!isHandRaiseLeadAvailable || document.querySelector('.js-hand-raise-lead-modal')) {
    return isHandRaiseLeadAvailable;
  }

  let mountPromise = null;

  const handleOpenModal = (options) => {
    mountPromise =
      mountPromise ||
      Promise.all([
        import(
          /* webpackChunkName: 'handRaiseLeadModal' */
          'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_modal.vue'
        ),
        import(/* webpackChunkName: 'handRaiseLeadModal' */ 'ee/subscriptions/graphql/graphql'),
      ]).then(([{ default: HandRaiseLeadModal }, { default: apolloProvider }]) => {
        const modalEl = document.createElement('div');
        document.body.appendChild(modalEl);

        const app = new Vue({
          name: 'HandRaiseLeadModalRoot',
          apolloProvider,
          render: (createElement) =>
            createElement(HandRaiseLeadModal, {
              ref: 'modal',
              props: {
                user: convertObjectPropsToCamelCase(JSON.parse(user)),
                submitPath,
              },
            }),
        }).$mount(modalEl);

        // The mounted modal registers its own 'openModal' listener, so stop
        // listening here to avoid handling later clicks twice.
        handRaiseLeadEventHub.$off('openModal', handleOpenModal);

        return app.$refs.modal;
      });

    mountPromise
      .then((modal) => modal.openModal(options))
      .catch((error) => Sentry.captureException(error));
  };

  handRaiseLeadEventHub.$on('openModal', handleOpenModal);

  return isHandRaiseLeadAvailable;
}
