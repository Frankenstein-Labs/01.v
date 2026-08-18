import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import PipelineAccountVerificationAlert from 'ee/vue_shared/components/pipeline_account_verification_alert.vue';

describe('Identity verification needed to run pipelines alert', () => {
  const DEFAULT_PROVIDES = { identityVerificationRequired: true };

  let wrapper;

  const createWrapper = ({ props, provide } = { props: {}, provide: {} }) => {
    wrapper = shallowMount(PipelineAccountVerificationAlert, {
      propsData: props,
      provide: {
        identityVerificationPath: 'identity/verification/path',
        ...DEFAULT_PROVIDES,
        ...provide,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('when identity verification is not required', () => {
    it('does not show alert', () => {
      createWrapper({ provide: { identityVerificationRequired: false } });

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when identity verification is required', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows alert with expected props', () => {
      expect(findAlert().props()).toMatchObject({
        title: 'Before you can run pipelines, we need to verify your account.',
        primaryButtonText: 'Verify my account',
        primaryButtonLink: 'identity/verification/path',
        variant: 'danger',
      });
    });

    it('shows alert with expected description', () => {
      expect(findAlert().text()).toBe(
        `We won't ask you for this information again. It will never be used for marketing purposes.`,
      );
    });

    it(`hides the alert when it's dismissed`, async () => {
      findAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('custom title', () => {
    it('shows alert with expected props', () => {
      createWrapper({ props: { title: 'Custom title' } });

      expect(findAlert().props()).toMatchObject({
        title: 'Custom title',
      });
    });
  });

  describe('dismissible', () => {
    it('is dismissible by default', () => {
      createWrapper();

      expect(findAlert().props('dismissible')).toBe(true);
    });

    it('can be made non-dismissible', () => {
      createWrapper({ props: { dismissible: false } });

      expect(findAlert().props('dismissible')).toBe(false);
    });
  });
});
