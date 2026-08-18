import { defineAsyncComponent } from 'vue';
import { initHandRaiseLead } from 'ee/hand_raise_leads/hand_raise_lead';
import EndOfTrialModal from 'ee/end_of_trial/components/end_of_trial_modal.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initHandRaiseLead();
initSimpleApp('#js-end-of-trial-modal', EndOfTrialModal, { withApolloProvider: true });
initSimpleApp(
  '#js-amazon-q-settings',
  // A bare `() => import(...)` factory is the Vue 2 async-component syntax;
  // plain Vue 3 treats it as a functional component and renders the returned
  // promise as literal "[object Promise]" text.
  defineAsyncComponent(
    () =>
      import(
        /* webpackChunkName: 'amazonQGroupSettings' */ 'ee/amazon_q_settings/components/group_settings_app.vue'
      ),
  ),
);
