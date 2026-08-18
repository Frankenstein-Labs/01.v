import { GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ToolApprovalForSessionSettings from 'ee/ai/settings/components/tool_approval_for_session_settings.vue';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';

describe('ToolApprovalForSessionSettings', () => {
  let wrapper;

  const defaultProvide = {
    isGroupSettings: false,
    toolApprovalForSessionCascadingSettings: {
      lockedByAncestor: false,
      lockedByApplicationSetting: false,
    },
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ToolApprovalForSessionSettings, {
      propsData: {
        toolApprovalForSessionAvailability: AVAILABILITY_OPTIONS.DEFAULT_OFF,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCascadingLockIcon = () => wrapper.findComponent(CascadingLockIcon);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().attributes('label')).toBe('Tool approval for sessions');
    });

    it('renders a dropdown with three options', () => {
      const dropdown = findDropdown();
      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props('items')).toHaveLength(3);
    });

    it('renders correct dropdown option labels', () => {
      const items = findDropdown().props('items');
      expect(items.map((i) => i.text)).toEqual(['On by default', 'Off by default', 'Always off']);
    });

    it('renders correct dropdown option values', () => {
      const items = findDropdown().props('items');
      expect(items.map((i) => i.value)).toEqual([
        AVAILABILITY_OPTIONS.DEFAULT_ON,
        AVAILABILITY_OPTIONS.DEFAULT_OFF,
        AVAILABILITY_OPTIONS.NEVER_ON,
      ]);
    });
  });

  describe('dropdown state', () => {
    it.each`
      availability                        | description
      ${AVAILABILITY_OPTIONS.DEFAULT_ON}  | ${'default_on'}
      ${AVAILABILITY_OPTIONS.DEFAULT_OFF} | ${'default_off'}
      ${AVAILABILITY_OPTIONS.NEVER_ON}    | ${'never_on'}
    `('sets initial selected value to $description', ({ availability }) => {
      createComponent({ props: { toolApprovalForSessionAvailability: availability } });

      expect(findDropdown().props('selected')).toBe(availability);
    });
  });

  describe('dropdown interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits change event when dropdown selection changes', () => {
      findDropdown().vm.$emit('select', AVAILABILITY_OPTIONS.DEFAULT_ON);

      expect(wrapper.emitted('change')).toEqual([[AVAILABILITY_OPTIONS.DEFAULT_ON]]);
    });
  });

  describe('dropdown items include secondary text', () => {
    it('includes group-specific secondary text when isGroupSettings is true', () => {
      createComponent({ provide: { isGroupSettings: true } });

      const items = findDropdown().props('items');
      expect(items[0].secondaryText).toBe(
        'Tool approval for sessions is available. Subgroups can turn it off.',
      );
      expect(items[2].secondaryText).toBe(
        'Tool approval for sessions is not available and cannot be turned on for any subgroup.',
      );
    });

    it('includes instance-specific secondary text when isGroupSettings is false', () => {
      createComponent({ provide: { isGroupSettings: false } });

      const items = findDropdown().props('items');
      expect(items[0].secondaryText).toBe(
        'Tool approval for sessions is available. Groups and subgroups can turn it off.',
      );
      expect(items[2].secondaryText).toBe(
        'Tool approval for sessions is not available and cannot be turned on for any group or subgroup.',
      );
    });
  });

  describe('disabled state', () => {
    it('does not disable dropdown by default', () => {
      createComponent();

      expect(findDropdown().props('disabled')).toBe(false);
    });

    it('disables dropdown when disabled prop is true', () => {
      createComponent({ props: { disabled: true } });

      expect(findDropdown().props('disabled')).toBe(true);
    });
  });

  describe('cascading lock icon', () => {
    it('does not render cascading lock by default', () => {
      createComponent();

      expect(findCascadingLockIcon().exists()).toBe(false);
    });

    it('does not render cascading lock when cascading settings is null', () => {
      createComponent({
        provide: {
          toolApprovalForSessionCascadingSettings: null,
        },
      });

      expect(findCascadingLockIcon().exists()).toBe(false);
      expect(findDropdown().props('disabled')).toBe(false);
    });

    describe('when locked by application setting', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            toolApprovalForSessionCascadingSettings: {
              lockedByAncestor: false,
              lockedByApplicationSetting: true,
            },
          },
        });
      });

      it('shows cascading lock icon', () => {
        expect(findCascadingLockIcon().exists()).toBe(true);
        expect(findCascadingLockIcon().props('isLockedByApplicationSettings')).toBe(true);
      });

      it('disables the dropdown', () => {
        expect(findDropdown().props('disabled')).toBe(true);
      });
    });

    describe('when locked by ancestor', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            toolApprovalForSessionCascadingSettings: {
              lockedByAncestor: true,
              lockedByApplicationSetting: false,
              ancestorNamespace: { path: 'parent-group', fullName: 'Parent Group' },
            },
          },
        });
      });

      it('shows cascading lock icon', () => {
        expect(findCascadingLockIcon().exists()).toBe(true);
        expect(findCascadingLockIcon().props('isLockedByGroupAncestor')).toBe(true);
      });

      it('disables the dropdown', () => {
        expect(findDropdown().props('disabled')).toBe(true);
      });
    });
  });
});
