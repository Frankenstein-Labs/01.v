import { nextTick } from 'vue';
import SamlMembershipRoleSelector from 'ee/saml_providers/saml_membership_role_selector/components/saml_membership_role_selector.vue';
import RoleSelector from 'ee/roles_and_permissions/components/role_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('SamlMembershipRoleSelector', () => {
  let wrapper;

  const defaultProvidedData = {
    currentStandardRole: 30,
    currentCustomRoleId: 10,
  };

  const createComponent = (providedData = {}) => {
    wrapper = shallowMountExtended(SamlMembershipRoleSelector, {
      provide: {
        ...defaultProvidedData,
        ...providedData,
      },
    });
  };

  const findStandardRoleInputElement = () => wrapper.findByTestId('selected-standard-role').element;
  const findCustomRoleInputElement = () => wrapper.findByTestId('selected-custom-role').element;
  const findSelectedStandardRole = () => findStandardRoleInputElement().value;
  const findSelectedCustomRole = () => findCustomRoleInputElement().value;
  const findRoleSelector = () => wrapper.findComponent(RoleSelector);

  describe('component', () => {
    describe('on mount', () => {
      beforeEach(() => {
        createComponent();
      });

      it('sets the correct initial value', () => {
        expect(findSelectedStandardRole()).toBe(defaultProvidedData.currentStandardRole.toString());
        expect(findSelectedCustomRole()).toBe(defaultProvidedData.currentCustomRoleId.toString());
      });
    });

    describe('`on-select` event fired', () => {
      beforeEach(() => {
        createComponent();
      });

      it('sets the correct values', async () => {
        const newStandardRoleValue = 20;
        const newCustomRoleValue = 12;

        await findRoleSelector().vm.$emit('on-select', {
          selectedStandardRoleValue: newStandardRoleValue,
          selectedCustomRoleValue: newCustomRoleValue,
        });

        expect(findSelectedStandardRole()).toBe(newStandardRoleValue.toString());
        expect(findSelectedCustomRole()).toBe(newCustomRoleValue.toString());
      });

      it('triggers an input event on the inputs', async () => {
        const standardRoleInputDispatchEventSpy = jest.spyOn(
          findStandardRoleInputElement(),
          'dispatchEvent',
        );
        const customRoleInputDispatchEventSpy = jest.spyOn(
          findCustomRoleInputElement(),
          'dispatchEvent',
        );

        await findRoleSelector().vm.$emit('on-select', {});
        await nextTick();

        expect(standardRoleInputDispatchEventSpy).toHaveBeenCalledWith(expect.any(Event));
        expect(standardRoleInputDispatchEventSpy.mock.calls[0][0].type).toBe('input');
        expect(customRoleInputDispatchEventSpy).toHaveBeenCalledWith(expect.any(Event));
        expect(customRoleInputDispatchEventSpy.mock.calls[0][0].type).toBe('input');
      });
    });
  });
});
