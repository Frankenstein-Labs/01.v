import '~/pages/registrations/new';
import { trackNewRegistrations } from 'ee/google_tag_manager';
import initPasswordValidator from 'ee/password/password_validator';
import { setupArkoseLabsForSignup } from 'ee/arkose_labs';
import FormErrorTracker from '~/pages/shared/form_error_tracker';
import { initOnboardingEmailOptIn } from 'ee/registrations/onboarding_email_opt_in';

trackNewRegistrations();

// Warning: initPasswordValidator has to run after initPasswordInput
// (which is executed when '~/pages/registrations/new' is imported)
initPasswordValidator();

setupArkoseLabsForSignup();

// Warning: run after all input initializations
// eslint-disable-next-line no-new
new FormErrorTracker();

initOnboardingEmailOptIn();
