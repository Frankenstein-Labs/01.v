import { mount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import UserLimitReachedAlert from 'ee_component/members/components/table/user_limit_reached_alert.vue';

describe('UserLimitReachedAlert', () => {
  let wrapper;

  const createComponent = (provide) => {
    wrapper = mount(UserLimitReachedAlert, {
      provide: {
        canApproveAccessRequests: true,
        namespaceUserLimit: 5,
        ...provide,
      },
    });
  };

  const findUserLimitReachedAlert = () => wrapper.findComponent(GlAlert);

  describe('when the user limit is reached (can not approve access requests)', () => {
    it('shows the alert', () => {
      createComponent({ canApproveAccessRequests: false });

      expect(findUserLimitReachedAlert().exists()).toBe(true);
      expect(findUserLimitReachedAlert().text()).toContain(
        'You can no longer accept access requests',
      );
      expect(findUserLimitReachedAlert().text()).toContain('5');
    });
  });

  describe('when the user limit is not reached (can approve access requests)', () => {
    it('does not show the alert', () => {
      createComponent();

      expect(findUserLimitReachedAlert().exists()).toBe(false);
    });
  });
});
