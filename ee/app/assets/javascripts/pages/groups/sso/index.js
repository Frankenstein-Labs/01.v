import { initSamlAuthorize, redirectUserWithSSOIdentity } from 'ee/saml_sso';
import { initLanguageSwitcher } from '~/language_switcher';
import { renderGFM } from '~/behaviors/markdown/render_gfm';

initSamlAuthorize();
redirectUserWithSSOIdentity();
initLanguageSwitcher();
renderGFM(document.getElementById('js-custom-sign-in-description'));
