import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';

describe('LimitedAccessModal', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(LimitedAccessModal, {
      propsData: { ...props },
    });
  };
  const findModal = () => wrapper.findComponent(GlModal);

  it('has correct button', () => {
    createComponent({ limitedAccessReason: 'MANAGED_BY_RESELLER' });

    expect(findModal().props('actionPrimary')).toStrictEqual({
      text: 'Close',
      attributes: { variant: 'confirm' },
    });
  });

  describe('with reseller', () => {
    beforeEach(() => {
      createComponent({ limitedAccessReason: 'MANAGED_BY_RESELLER' });
    });

    it('shows correct content', () => {
      const modal = findModal();

      expect(modal.text()).toContain('GitLab Partner');
    });
  });
});
