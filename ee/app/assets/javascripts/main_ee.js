import initEETrialBanner from 'ee/ee_trial_banner';
import { initSamlReloadModal } from 'ee/saml_sso/index';
import { initDuoPanel } from 'ee/ai/init_duo_panel';

// EE specific calls
initEETrialBanner();

initSamlReloadModal();

initDuoPanel();
