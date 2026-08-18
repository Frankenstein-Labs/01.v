import { GlAlert } from '@gitlab/ui';
import { createWrapper } from '@vue/test-utils';
import { initDuoAgentsPlatformVerificationAlert } from 'ee/ai/duo_agents_platform/init_verification_alert';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';

describe('initDuoAgentsPlatformVerificationAlert', () => {
  let app;

  const findAlert = () => createWrapper(app).findComponent(GlAlert);

  afterEach(() => {
    app?.$destroy();
    app = undefined;
    resetHTMLFixture();
  });

  describe('when the mount element is missing', () => {
    it('returns null and renders nothing', () => {
      setHTMLFixture('<div></div>');

      expect(initDuoAgentsPlatformVerificationAlert()).toBe(null);
    });
  });

  describe('when verification is required', () => {
    beforeEach(() => {
      setHTMLFixture(
        `<div class="js-duo-agents-platform-verification-alert"
              data-identity-verification-required="true"
              data-identity-verification-path="/-/identity_verification"></div>`,
      );
      app = initDuoAgentsPlatformVerificationAlert();
    });

    it('mounts the verification alert', () => {
      expect(app).not.toBe(null);
      expect(findAlert().exists()).toBe(true);
    });

    it('links the verify button to the identity verification path', () => {
      expect(findAlert().props('primaryButtonLink')).toBe('/-/identity_verification');
    });
  });

  // Unreachable in the DAP flow (the Haml only mounts when required), but kept to cover
  // the init's dataset parse forwarding `false` through to the shared component's v-if.
  describe('when verification is not required', () => {
    beforeEach(() => {
      setHTMLFixture(
        `<div class="js-duo-agents-platform-verification-alert"
              data-identity-verification-required="false"
              data-identity-verification-path="/-/identity_verification"></div>`,
      );
      app = initDuoAgentsPlatformVerificationAlert();
    });

    it('mounts but renders no alert', () => {
      expect(app).not.toBe(null);
      expect(findAlert().exists()).toBe(false);
    });
  });
});
