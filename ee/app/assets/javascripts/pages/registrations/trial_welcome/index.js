import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import TrialWelcomeForm from 'ee/registrations/components/trial_welcome_form.vue';

initSimpleApp('#js-create-trial-welcome-form', TrialWelcomeForm, {
  withApolloProvider: apolloProvider,
});
