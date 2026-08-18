import '~/pages/projects';
import { initHandRaiseLead } from 'ee/hand_raise_leads/hand_raise_lead';
import EndOfTrialModal from 'ee/end_of_trial/components/end_of_trial_modal.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initHandRaiseLead();
initSimpleApp('#js-end-of-trial-modal', EndOfTrialModal, { withApolloProvider: true });
