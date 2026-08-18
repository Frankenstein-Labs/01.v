import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CreateTrialForm from 'ee/trials/components/create_trial_form.vue';

initSimpleApp('#js-create-trial-form', CreateTrialForm, { withApolloProvider: apolloProvider });
