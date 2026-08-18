import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupCnFormGroup from 'ee/roles_and_permissions/components/ldap_sync/group_cn_form_group.vue';
import Api from 'ee/api';
import { createAlert } from '~/alert';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { glFormGroupStub } from './helpers';

jest.mock('~/alert');
jest.mock('ee/api', () => ({
  ldapGroups: jest.fn().mockResolvedValue({ data: [{ cn: 'group1' }, { cn: 'group2' }] }),
}));

describe('GroupCnFormGroup component', () => {
  let wrapper;
  let debounceSpy;

  const createWrapper = ({
    value,
    server = 'ldapmain',
    state = true,
    disabled = false,
    mockTooltipDirective = true,
  } = {}) => {
    wrapper = shallowMountExtended(GroupCnFormGroup, {
      propsData: { value, server, state, disabled },
      stubs: { GlFormGroup: glFormGroupStub },
      // For some reason, mocking the tooltip directive causes Vue 3 to fail the "fetches group data
      // for new server with search term" test because the search term is reset. So we need to skip
      // the mock directive, otherwise the test will pass using Vue 2 but not Vue 3.
      directives: mockTooltipDirective ? { GlTooltip: createMockDirective('gl-tooltip') } : null,
    });

    debounceSpy = jest.spyOn(wrapper.vm, 'debouncedFetchGroups');
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findTooltip = () => getBinding(findDropdown().element, 'gl-tooltip');

  it('shows form group', () => {
    createWrapper();

    expect(findFormGroup().props()).toMatchObject({
      label: 'Group cn',
      invalidFeedback: 'This field is required',
    });
  });

  it('shows the dropdown', () => {
    createWrapper();

    expect(findDropdown().attributes('class')).toBe('gl-max-w-30');
    expect(findDropdown().props()).toMatchObject({
      selected: null,
      items: [],
      category: 'secondary',
      variant: 'default',
      toggleText: 'Select LDAP group',
      searchable: true,
      block: true,
    });
  });

  it('passes value prop to dropdown', () => {
    createWrapper({ value: 'group1' });

    expect(findDropdown().props('selected')).toBe('group1');
  });

  it.each([true, false])('passes disabled prop with value %s to dropdown', (disabled) => {
    createWrapper({ disabled });

    expect(findDropdown().props('disabled')).toBe(disabled);
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

    it('sets dropdown variant to $variant', () => {
      expect(findDropdown().props('variant')).toBe(variant);
    });
  });

  describe('when dropdown item is selected', () => {
    beforeEach(() => {
      createWrapper({ value: 'group1' });
      findDropdown().vm.$emit('select', 'group1');
    });

    it('emits input event with item value', () => {
      expect(wrapper.emitted('input')[0][0]).toBe('group1');
    });

    it('sets toggle text to item value', () => {
      expect(findDropdown().props('toggleText')).toBe('group1');
    });
  });

  describe('when server prop is null', () => {
    beforeEach(() => createWrapper({ server: null }));

    it('does not fetch groups data', () => {
      expect(Api.ldapGroups).not.toHaveBeenCalled();
    });

    it('disables the dropdown', () => {
      expect(findDropdown().props('disabled')).toBe(true);
    });

    it('shows tooltip', () => {
      expect(findTooltip()).toEqual({
        value: 'Select a server to fetch groups.',
        modifiers: { d0: true },
      });
    });
  });

  describe('when server prop has a value', () => {
    beforeEach(() => createWrapper({ server: 'ldapmain' }));

    it('fetches group data immediately', () => {
      expect(Api.ldapGroups).toHaveBeenCalledTimes(1);
      expect(Api.ldapGroups).toHaveBeenCalledWith('', 'ldapmain');
      expect(debounceSpy).not.toHaveBeenCalled();
    });

    it('enables the dropdown', () => {
      expect(findDropdown().props('disabled')).toBe(false);
    });

    it('does not show tooltip', () => {
      expect(findTooltip().value).toBe('');
    });
  });

  describe('when group data is loading', () => {
    it('shows loading spinner in dropdown', () => {
      createWrapper();

      expect(findDropdown().props('searching')).toBe(true);
    });

    it('shows selected item name', () => {
      createWrapper({ value: 'group1' });

      expect(findDropdown().props('toggleText')).toBe('group1');
    });
  });

  describe('when group data is fetched', () => {
    beforeEach(() => createWrapper());

    it('hides loading spinner', () => {
      expect(findDropdown().props('searching')).toBe(false);
    });

    it('passes fetched groups to dropdown', () => {
      expect(findDropdown().props('items')).toEqual([
        { value: 'group1', text: 'group1' },
        { value: 'group2', text: 'group2' },
      ]);
    });
  });

  describe('when user enters a search term', () => {
    beforeEach(() => {
      createWrapper({ value: 'group1', mockTooltipDirective: false });
      findDropdown().vm.$emit('search', 'ex');
    });

    it('fetches group data with search term after a small delay', () => {
      expect(Api.ldapGroups).toHaveBeenLastCalledWith('ex', 'ldapmain');
      expect(debounceSpy).toHaveBeenCalledTimes(1);
    });

    it('shows selected value in dropdown', () => {
      // This verifies that even if the search results don't contain the selected item, the selected
      // item is still shown in the dropdown toggle button.
      expect(findDropdown().props('toggleText')).toBe('group1');
    });

    describe('when the server is changed', () => {
      beforeEach(() => wrapper.setProps({ server: 'ldapalt' }));

      it('fetches group data for new server with search term', () => {
        expect(Api.ldapGroups).toHaveBeenLastCalledWith('ex', 'ldapalt');
      });
    });
  });

  describe('when groups data could not be fetched', () => {
    beforeEach(() => {
      Api.ldapGroups.mockRejectedValue();
      createWrapper();
    });

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Could not fetch LDAP groups. Please try again.',
      });
    });
  });
});
