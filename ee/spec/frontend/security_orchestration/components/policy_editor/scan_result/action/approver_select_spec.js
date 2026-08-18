import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import ApproverSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/approver_select.vue';
import { EMPTY_TYPE, GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import GroupSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/group_select.vue';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';
import RoleSelect from 'ee/security_orchestration/components/shared/role_select.vue';

describe('ApproverSelect', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(ApproverSelect, {
      propsData,
      stubs,
    });
  };

  const findTypeSelector = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findApproverComponent = () => wrapper.findComponentByTestId('approver-items');
  const findAdditionalText = () => wrapper.findByTestId('additional-text');

  describe('default rendering', () => {
    it('renders default component state', () => {
      createComponent();

      expect(findTypeSelector().props('selected')).toBe('');
      expect(findSectionLayout().props('showRemoveButton')).toBe(false);
      expect(findApproverComponent().exists()).toBe(false);
      expect(findAdditionalText().exists()).toBe(false);
    });
  });

  describe('rendering active component', () => {
    it.each`
      type          | component      | toggleText
      ${GROUP_TYPE} | ${GroupSelect} | ${'Groups'}
      ${ROLE_TYPE}  | ${RoleSelect}  | ${'Roles'}
      ${USER_TYPE}  | ${UserSelect}  | ${'Individual users'}
    `('renders active component based on selected type', ({ type, component, toggleText }) => {
      createComponent({
        propsData: {
          selectedType: type,
        },
      });

      expect(wrapper.findComponent(component).exists()).toBe(true);
      expect(findTypeSelector().props('toggleText')).toBe(toggleText);
    });

    it('does not render active component based for empty type', () => {
      createComponent({
        propsData: {
          selectedType: EMPTY_TYPE,
        },
      });

      expect(wrapper.findComponent(UserSelect).exists()).toBe(false);
      expect(wrapper.findComponent(GroupSelect).exists()).toBe(false);
      expect(wrapper.findComponent(RoleSelect).exists()).toBe(false);
      expect(findTypeSelector().props('toggleText')).toBe('Choose approver type');
    });
  });

  describe('additional text', () => {
    it('renders additional text', () => {
      createComponent({
        propsData: { showAdditionalText: true },
      });

      expect(findAdditionalText().exists()).toBe(true);
    });

    it('renders remove button', () => {
      createComponent({
        propsData: { showRemoveButton: true },
      });

      expect(findSectionLayout().props('showRemoveButton')).toBe(true);
    });
  });

  describe('selected items', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selectedType: GROUP_TYPE,
          selectedItems: [1, 2],
          selectedNames: ['name'],
        },
      });
    });

    it('renders selected items', () => {
      expect(findApproverComponent().props('selected')).toEqual([1, 2]);
      expect(findApproverComponent().props('selectedNames')).toEqual(['name']);
    });

    it('emits selected items', async () => {
      await findApproverComponent().vm.$emit('select-items', [3, 4]);

      expect(wrapper.emitted('select-items')).toEqual([[[3, 4]]]);
    });
  });

  describe('disabled items', () => {
    it('disables type selector', () => {
      createComponent({
        propsData: {
          disabled: true,
        },
      });

      expect(findTypeSelector().props('disabled')).toBe(true);
    });

    it('does not render a badge for disabled types', () => {
      createComponent({
        propsData: {
          selectedType: GROUP_TYPE,
          disabledTypes: [USER_TYPE],
        },
        stubs: {
          GlCollapsibleListbox,
        },
      });

      expect(wrapper.find('gl-badge-stub').exists()).toBe(false);
    });
  });

  describe('error state', () => {
    it('renders component error state', () => {
      createComponent({
        propsData: {
          selectedType: GROUP_TYPE,
          errors: [
            {
              index: 0,
              field: 'actions',
            },
            {
              index: 1,
              field: 'actions',
            },
          ],
        },
      });

      expect(wrapper.findComponent(GroupSelect).props('state')).toBe(false);
    });

    it('does not render component error state when errors are not for approvers type', () => {
      createComponent({
        propsData: {
          selectedType: GROUP_TYPE,
          errors: [
            {
              index: 0,
              field: 'not_approvers',
            },
            {
              index: 1,
              field: 'not_approvers',
            },
          ],
        },
      });

      expect(wrapper.findComponent(GroupSelect).props('state')).toBe(true);
    });
  });
});
