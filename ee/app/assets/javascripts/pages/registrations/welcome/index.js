import 'ee/registrations/welcome/jobs_to_be_done';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import FreeWelcomeForm from 'ee/registrations/components/free_welcome_form.vue';
import { saasTrialWelcome } from 'ee/google_tag_manager';
import Tracking from '~/tracking';
import FormErrorTracker from '~/pages/shared/form_error_tracker';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

saasTrialWelcome();
Tracking.enableFormTracking({
  forms: { allow: ['js-users-signup-welcome'] },
});

// Warning: run after all input initializations
// eslint-disable-next-line no-new
new FormErrorTracker();

initSimpleApp('#js-free-welcome-form', FreeWelcomeForm, {
  withApolloProvider: apolloProvider,
});
