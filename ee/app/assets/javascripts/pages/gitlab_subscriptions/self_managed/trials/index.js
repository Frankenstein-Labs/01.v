import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CreateTrialForm from './components/create_trial_form.vue';

initSimpleApp('#js-start-trial-form', CreateTrialForm, {
  withApolloProvider: apolloProvider,
});
