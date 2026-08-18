import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import EnvironmentApproval from 'ee/environments/components/environment_approval.vue';

describe('ee/environments/components/environment_approval.vue', () => {
  let wrapper;

  const deploymentWebPath = '/path/to/deployment';

  const defaultProps = {
    requiredApprovalCount: 1,
    deploymentWebPath,
    showText: true,
    status: 'running',
  };

  const createWrapper = (propsData = {}) => {
    wrapper = shallowMount(EnvironmentApproval, {
      propsData: { ...defaultProps, ...propsData },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);

  describe('button', () => {
    it('shows the button linking to the deployments details page if requiredApprovalCount > 0', () => {
      createWrapper();
      expect(findButton().attributes('href')).toBe(deploymentWebPath);
    });

    it("doesn't show the button if requiredApprovalCount = 0", () => {
      createWrapper({
        requiredApprovalCount: 0,
      });

      expect(findButton().exists()).toBe(false);
    });

    it("doesn't show the button if status is finished", () => {
      createWrapper({
        status: 'FAILED',
      });

      expect(findButton().exists()).toBe(false);
    });
  });

  describe('showing text', () => {
    it('should show text by default', () => {
      createWrapper();

      expect(findButton().text()).toBe('Approval options');
    });

    it('should hide the text if show text is false, and put it in the title', () => {
      createWrapper({ showText: false });

      expect(findButton().text()).toBe('');
      expect(findButton().attributes('title')).toBe('Approval options');
    });
  });

  describe('size', () => {
    it('should render medium button by default', () => {
      createWrapper();

      expect(findButton().props('size')).toBe('medium');
    });

    it('should render a small button if provided', () => {
      createWrapper({ size: 'small' });

      expect(findButton().props('size')).toBe('small');
    });
  });
});
