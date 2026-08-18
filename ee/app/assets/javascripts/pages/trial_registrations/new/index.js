import '~/pages/sessions/index';
import { trackFreeTrialAccountSubmissions } from 'ee/google_tag_manager';

import NoEmojiValidator from '~/emoji/no_emoji_validator';
import LengthValidator from '~/validators/length_validator';
import SigninTabsMemoizer from '~/pages/sessions/new/signin_tabs_memoizer';
import UsernameValidator from '~/pages/sessions/new/username_validator';
import EmailFormatValidator from '~/pages/sessions/new/email_format_validator';
import Tracking from '~/tracking';
import { setupArkoseLabsForSignup } from 'ee/arkose_labs';
import initPasswordValidator from 'ee/password/password_validator';
import { initPasswordInput } from '~/authentication/password';
import { initLanguageSwitcher } from '~/language_switcher';
import FormErrorTracker from '~/pages/shared/form_error_tracker';
import { initOnboardingEmailOptIn } from 'ee/registrations/onboarding_email_opt_in';
import { initSignupSubmitButton } from '~/registrations/signup_submit_button';

new UsernameValidator(); // eslint-disable-line no-new
new LengthValidator(); // eslint-disable-line no-new
new SigninTabsMemoizer(); // eslint-disable-line no-new
new NoEmojiValidator(); // eslint-disable-line no-new
new EmailFormatValidator(); // eslint-disable-line no-new

trackFreeTrialAccountSubmissions();

Tracking.enableFormTracking({
  forms: { allow: ['new_user'] },
});

setupArkoseLabsForSignup();
initPasswordInput();
// Warning: initPasswordValidator has to run after initPasswordInput
initPasswordValidator();
initLanguageSwitcher();

// Warning: run after all input initializations
// eslint-disable-next-line no-new
new FormErrorTracker();

initOnboardingEmailOptIn();
initSignupSubmitButton();
