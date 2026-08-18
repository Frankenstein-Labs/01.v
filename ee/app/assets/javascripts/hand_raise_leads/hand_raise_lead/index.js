import * as Sentry from '~/sentry/sentry_browser_wrapper';
import eventHub from './event_hub';

export function initHandRaiseLead() {
  const modalEl = document.querySelector('.js-hand-raise-lead-modal');

  if (modalEl) {
    // The modal is mounted through a dynamic import, but its trigger is clickable as
    // soon as the page renders. `openModal` is fire-and-forget, so a click landing
    // before the modal has registered its own listener was dropped entirely: the
    // button did nothing and nothing was reported. Hold such a click and replay it
    // once the modal is listening.
    let pendingOptions;
    const holdOpenModal = (options) => {
      pendingOptions = options ?? {};
    };
    eventHub.$on('openModal', holdOpenModal);

    import(/* webpackChunkName: 'initHandRaiseLeadModal' */ './init_hand_raise_lead_modal')
      .then(({ default: initHandRaiseLeadModal }) => {
        initHandRaiseLeadModal();
        eventHub.$off('openModal', holdOpenModal);

        if (pendingOptions) {
          eventHub.$emit('openModal', pendingOptions);
        }
      })
      .catch((error) => {
        eventHub.$off('openModal', holdOpenModal);
        Sentry.captureException(error);
      });
  }

  const handRaiseLeadButton = document.querySelector('.js-hand-raise-lead-trigger');
  if (!handRaiseLeadButton) return;

  import(/* webpackChunkName: 'initHandRaiseLeadButton' */ './init_hand_raise_lead_button')
    .then(({ default: initHandRaiseLeadButton }) => {
      initHandRaiseLeadButton();
    })
    .catch((error) => Sentry.captureException(error));
}
