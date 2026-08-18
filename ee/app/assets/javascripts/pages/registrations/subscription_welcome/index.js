import SubscriptionWelcomeForm from 'ee/registrations/components/subscription_welcome_form.vue';
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

initSimpleApp('#js-subscription-welcome-form', SubscriptionWelcomeForm);
