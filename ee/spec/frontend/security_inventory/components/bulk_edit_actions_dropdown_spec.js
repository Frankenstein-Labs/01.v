import { shallowMount } from '@vue/test-utils';
import { GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import BulkEditActionsDropdown from 'ee/security_inventory/components/bulk_edit_actions_dropdown.vue';
import {
  ACTION_TYPE_BULK_EDIT_ATTRIBUTES,
  ACTION_TYPE_BULK_EDIT_SCANNERS,
} from 'ee/security_inventory/constants';

describe('BulkEditActionsDropdown', () => {
  let wrapper;

  const createComponent = (provide = {}) => {
    wrapper = shallowMount(BulkEditActionsDropdown, {
      provide: {
        canManageAttributes: false,
        canApplyProfiles: false,
        ...provide,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  describe('when user has both canManageAttributes and canApplyProfiles permissions', () => {
    beforeEach(() => {
      createComponent({
        canManageAttributes: true,
        canApplyProfiles: true,
      });
    });

    it('renders dropdown with "Manage security scanners" and "Manage security attributes" actions', () => {
      const dropdown = findDropdown();
      const items = dropdown.props('items');

      expect(items).toHaveLength(2);
      expect(items[0]).toMatchObject({
        text: 'Manage security scanners',
        type: ACTION_TYPE_BULK_EDIT_SCANNERS,
      });
      expect(items[1]).toMatchObject({
        text: 'Manage security attributes',
        type: ACTION_TYPE_BULK_EDIT_ATTRIBUTES,
      });
    });

    it('emits bulk-edit event with SCANNERS type when scanners action is clicked', () => {
      const dropdownItems = findDropdownItems();
      dropdownItems.at(0).vm.$emit('action');

      expect(wrapper.emitted('bulk-edit')).toEqual([[ACTION_TYPE_BULK_EDIT_SCANNERS]]);
    });

    it('emits bulk-edit event with ATTRIBUTES type when attributes action is clicked', () => {
      const dropdownItems = findDropdownItems();
      dropdownItems.at(1).vm.$emit('action');

      expect(wrapper.emitted('bulk-edit')).toEqual([[ACTION_TYPE_BULK_EDIT_ATTRIBUTES]]);
    });
  });

  describe('when user only has canApplyProfiles permission', () => {
    beforeEach(() => {
      createComponent({
        canManageAttributes: false,
        canApplyProfiles: true,
      });
    });

    it('renders dropdown with only scanners action', () => {
      const dropdown = findDropdown();
      const items = dropdown.props('items');

      expect(items).toHaveLength(1);
      expect(items[0]).toMatchObject({
        text: 'Manage security scanners',
        type: ACTION_TYPE_BULK_EDIT_SCANNERS,
      });
    });
  });

  describe('when user only has canManageAttributes permission', () => {
    beforeEach(() => {
      createComponent({
        canManageAttributes: true,
        canApplyProfiles: false,
      });
    });

    it('renders dropdown with only attributes action', () => {
      const dropdown = findDropdown();
      const items = dropdown.props('items');

      expect(items).toHaveLength(1);
      expect(items[0]).toMatchObject({
        text: 'Manage security attributes',
        type: ACTION_TYPE_BULK_EDIT_ATTRIBUTES,
      });
    });
  });
});
