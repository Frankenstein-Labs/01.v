import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServerFormGroup from 'ee/roles_and_permissions/components/ldap_sync/server_form_group.vue';
import { ldapServers } from '../../mock_data';
import { glFormGroupStub } from './helpers';

describe('ServerFormGroup component', () => {
  let wrapper;

  const createWrapper = ({ value, state = true, disabled = false } = {}) => {
    wrapper = shallowMountExtended(ServerFormGroup, {
      propsData: { value, state, disabled },
      provide: { ldapServers },
      stubs: { GlFormGroup: glFormGroupStub },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('on page load', () => {
    beforeEach(() => createWrapper());

    it('shows form group', () => {
      expect(findFormGroup().props()).toMatchObject({
        label: 'Server',
        invalidFeedback: 'This field is required',
      });
    });

    it('shows the dropdown', () => {
      expect(findDropdown().attributes('class')).toBe('gl-max-w-30');
      expect(findDropdown().props()).toMatchObject({
        selected: null,
        items: ldapServers,
        category: 'secondary',
        toggleText: 'Select server',
        block: true,
      });
    });

    it('emits input event when dropdown item is selected', () => {
      findDropdown().vm.$emit('select', 'group1');

      expect(wrapper.emitted('input')[0][0]).toBe('group1');
    });

    it.each([true, false])('passes disabled prop with value %s to dropdown', async (disabled) => {
      await wrapper.setProps({ disabled });

      expect(findDropdown().props('disabled')).toBe(disabled);
    });
  });

  describe('when value prop has a value', () => {
    beforeEach(() => createWrapper({ value: 'ldapmain' }));

    it('passes value to dropdown', () => {
      expect(findDropdown().props('selected')).toBe('ldapmain');
    });

    it('sets toggle text to empty string', () => {
      // Empty string makes the dropdown use its default behavior of showing the selected item's
      // text.
      expect(findDropdown().props('toggleText')).toBe('');
    });
  });

  describe.each`
    state    | variant
    ${true}  | ${'default'}
    ${false} | ${'danger'}
  `('when state prop is $state', ({ state, variant }) => {
    beforeEach(() => createWrapper({ state }));

    it('passes state value to form group', () => {
      expect(findFormGroup().props('state')).toBe(state);
    });

    it(`sets dropdown variant to ${variant}`, () => {
      expect(findDropdown().props('variant')).toBe(variant);
    });
  });
});
