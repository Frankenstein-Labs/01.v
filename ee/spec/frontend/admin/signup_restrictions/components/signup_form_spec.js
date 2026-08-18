import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { SEAT_CONTROL } from 'ee/pages/admin/application_settings/general/constants';
import SeatControlSection from 'ee_component/pages/admin/application_settings/general/components/seat_control_section.vue';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockData } from 'jest/admin/signup_restrictions/mock_data';
import SignupForm from '~/pages/admin/application_settings/general/components/signup_form.vue';
import BeforeSubmitApproveUsersModal from '~/pages/admin/application_settings/general/components/before_submit_approve_users_modal.vue';

describe('SignUpRestrictionsApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let formSubmitSpy;

  const findForm = () => wrapper.findByTestId('form');
  const findModal = () => wrapper.findComponent(BeforeSubmitApproveUsersModal);
  const findSeatControlSection = () => wrapper.findComponent(SeatControlSection);
  const findAutoApprovePendingUsersField = () =>
    wrapper.find('[name="application_setting[auto_approve_pending_users]"]');
  const findFormSubmitButton = () => findForm().findComponent(GlButton);

  const mountComponent = ({ provide = {} } = {}) => {
    wrapper = mountExtended(SignupForm, {
      provide: {
        glLicensedFeatures: { passwordComplexity: true, seatControl: true },
        ...mockData,
        ...provide,
      },
      stubs: {
        SignupCheckbox: true,
      },
    });
  };

  afterEach(() => {
    formSubmitSpy = null;
  });

  describe('form data', () => {
    beforeEach(async () => {
      mountComponent({
        provide: {
          canDisableMemberPromotionManagement: false,
          rolePromotionRequestsPath: '',
        },
      });

      await waitForPromises();
    });

    it.each`
      prop                                 | propValue                                   | elementSelector                                                       | formElementPassedDataType | formElementKey | expected
      ${'passwordNumberRequired'}          | ${mockData.passwordNumberRequired}          | ${'[name="application_setting[password_number_required]"]'}           | ${'prop'}                 | ${'value'}     | ${mockData.passwordNumberRequired}
      ${'passwordLowercaseRequired'}       | ${mockData.passwordLowercaseRequired}       | ${'[name="application_setting[password_lowercase_required]"]'}        | ${'prop'}                 | ${'value'}     | ${mockData.passwordLowercaseRequired}
      ${'passwordUppercaseRequired'}       | ${mockData.passwordUppercaseRequired}       | ${'[name="application_setting[password_uppercase_required]"]'}        | ${'prop'}                 | ${'value'}     | ${mockData.passwordUppercaseRequired}
      ${'passwordSymbolRequired'}          | ${mockData.passwordSymbolRequired}          | ${'[name="application_setting[password_symbol_required]"]'}           | ${'prop'}                 | ${'value'}     | ${mockData.passwordSymbolRequired}
      ${'enableMemberPromotionManagement'} | ${mockData.enableMemberPromotionManagement} | ${'[name="application_setting[enable_member_promotion_management]"]'} | ${'prop'}                 | ${'value'}     | ${mockData.enableMemberPromotionManagement}
    `(
      'form element $elementSelector gets $expected value for $formElementKey $formElementPassedDataType when prop $prop is set to $propValue',
      ({ elementSelector, expected, formElementKey, formElementPassedDataType }) => {
        const formElement = wrapper.find(elementSelector);

        switch (formElementPassedDataType) {
          case 'attribute':
            expect(formElement.attributes(formElementKey)).toBe(expected);
            break;
          case 'prop':
            expect(wrapper.findComponent(elementSelector).props(formElementKey)).toBe(expected);
            break;
          case 'value':
            expect(formElement.element.value).toBe(expected);
            break;
          default:
            expect(wrapper.findComponent(elementSelector).props(formElementKey)).toBe(expected);
            break;
        }
      },
    );
  });

  describe('with the approve users modal', () => {
    beforeEach(() => {
      const INITIAL_USER_CAP = 5;
      const INITIAL_SEAT_CONTROL = SEAT_CONTROL.USER_CAP;

      mountComponent({
        provide: {
          newUserSignupsCap: INITIAL_USER_CAP,
          seatControl: INITIAL_SEAT_CONTROL,
          pendingUserCount: 5,
        },
        stubs: {
          GlButton,
          BeforeSubmitApproveUsersModal: stubComponent(BeforeSubmitApproveUsersModal),
        },
      });

      findSeatControlSection().vm.$emit('check-users-auto-approval', true);

      findFormSubmitButton().trigger('click');

      return nextTick();
    });

    describe('when clicking approve users button', () => {
      beforeEach(() => {
        formSubmitSpy = jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation();

        findModal().vm.$emit('primary');

        return nextTick();
      });

      it('submits the form', () => {
        expect(formSubmitSpy).toHaveBeenCalled();
      });

      it('submits the form with the correct value', () => {
        expect(findAutoApprovePendingUsersField().attributes('value')).toBe('true');
      });
    });

    describe('when clicking proceed without approve button', () => {
      beforeEach(() => {
        formSubmitSpy = jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation();

        findModal().vm.$emit('secondary');

        return nextTick();
      });

      it('submits the form', () => {
        expect(formSubmitSpy).toHaveBeenCalled();
      });

      it('submits the form with the correct value', () => {
        expect(findAutoApprovePendingUsersField().attributes('value')).toBe('false');
      });
    });
  });
});
