import { GlAlert } from '@gitlab/ui';
import SeatControlMemberPromotionManagement from 'ee/pages/admin/application_settings/general/components/seat_control_member_promotion_management.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SignupCheckbox from '~/pages/admin/application_settings/general/components/signup_checkbox.vue';

describe('SeatControlMemberPromotionManagement', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findSignupCheckbox = () => wrapper.findComponent(SignupCheckbox);

  const mountComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(SeatControlMemberPromotionManagement, {
      provide: {
        enableMemberPromotionManagement: true,
        canDisableMemberPromotionManagement: false,
        rolePromotionRequestsPath: '/admin/role_promotion',
        ...provide,
      },
    });
  };

  it('will pass the prop to the SignupCheckbox', () => {
    mountComponent();

    expect(findSignupCheckbox().props('value')).toBe(true);
  });

  describe('prevent disabling setting', () => {
    it.each`
      canDisableMemberPromotionManagement | alertShown
      ${false}                            | ${true}
      ${true}                             | ${false}
    `(
      'ensures alert existence is related with canDisableMemberPromotionManagement value',
      ({ canDisableMemberPromotionManagement, alertShown }) => {
        mountComponent({
          provide: {
            canDisableMemberPromotionManagement,
          },
        });

        const findAlert = () => wrapper.findComponent(GlAlert);

        expect(findAlert().exists()).toBe(alertShown);
      },
    );
  });
});
