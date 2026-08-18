import EETrialBanner from './ee_trial_banner';

export default function initEETrialBanner() {
  const trialBanner = document.querySelector('.js-gitlab-ee-license-banner');
  if (trialBanner) {
    new EETrialBanner(trialBanner).init();
  }
}
