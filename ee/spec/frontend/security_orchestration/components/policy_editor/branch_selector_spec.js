import { nextTick } from 'vue';
import { GlDisclosureDropdown, GlListboxItem, GlModal } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import BranchSelector from 'ee/security_orchestration/components/policy_editor/branch_selector.vue';
import BranchSelectorModal from 'ee/security_orchestration/components/policy_editor/branch_selector_modal.vue';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import {
  APPROVAL_POLICY_TYPE,
  SCAN_EXECUTION_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import * as urlUtils from '~/lib/utils/url_utility';

describe('BranchSelector', () => {
  let wrapper;
  const closeMock = jest.fn();
  const openMock = jest.fn();

  const VALID_BRANCHES = [
    {
      fullPath: 'project',
      name: 'test',
      value: 'test@project',
    },
    {
      fullPath: 'project',
      name: 'test1',
      value: 'test1@project',
    },
  ];

  const VALID_BRANCHES_YAML_FORMAT = [
    {
      full_path: 'project',
      name: 'test',
    },
    {
      full_path: 'project',
      name: 'test1',
    },
  ];

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = mountExtended(BranchSelector, {
      propsData,
      provide: {
        namespacePath: 'namespacePath',
        policyType: APPROVAL_POLICY_TYPE,
      },
      stubs: {
        GlDisclosureDropdown: stubComponent(GlDisclosureDropdown, {
          methods: {
            open: openMock,
            close: closeMock,
          },
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findAllListboxItems = () => wrapper.findAllComponents(GlListboxItem);
  const findBranchSelectorModal = () => wrapper.findComponent(BranchSelectorModal);
  const findModal = () => findBranchSelectorModal().findComponent(GlModal);
  const findEmptyState = () => wrapper.findByTestId('empty-state');
  const findResetButton = () => wrapper.findComponentByTestId('reset-button');
  const findAddButton = () => wrapper.findByTestId('add-button');

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterValues').mockReturnValue([APPROVAL_POLICY_TYPE]);
  });

  describe('initial state for regular branches', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should render required components', () => {
      expect(findDropdown().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(true);
      expect(findResetButton().exists()).toBe(false);
      expect(findBranchSelectorModal().exists()).toBe(true);
      expect(findModal().props('visible')).toBe(false);

      expect(findDropdown().props('toggleText')).toBe('choose exception branches');
    });

    it('selects branches', () => {
      expect(findBranchSelectorModal().exists()).toBe(true);
      expect(findBranchSelectorModal().props('forProtectedBranches')).toBe(true);

      findBranchSelectorModal().vm.$emit('add-branches', VALID_BRANCHES);
      expect(openMock).toHaveBeenCalled();

      findDropdown().vm.$emit('hidden');

      expect(closeMock).toHaveBeenCalled();
      expect(wrapper.emitted('select-branches')[0]).toEqual([VALID_BRANCHES_YAML_FORMAT]);
    });
  });

  describe('existing exceptions', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selectedExceptions: VALID_BRANCHES_YAML_FORMAT,
        },
      });
    });

    it('renders existing exceptions', () => {
      expect(findAllListboxItems()).toHaveLength(VALID_BRANCHES_YAML_FORMAT.length);
      expect(findDropdown().props('toggleText')).toBe('test, test1');
      expect(findAddButton().exists()).toBe(true);
      expect(findResetButton().exists()).toBe(true);
      expect(findBranchSelectorModal().props('hasValidation')).toBe(false);
    });

    it('resets all branches', async () => {
      findResetButton().vm.$emit('click');
      await nextTick();

      expect(findEmptyState().exists()).toBe(true);
      expect(wrapper.emitted('select-branches')).toEqual([[[]]]);
    });

    it('unselects single branch', () => {
      findAllListboxItems().at(0).vm.$emit('select');
      findDropdown().vm.$emit('hidden');

      expect(closeMock).toHaveBeenCalled();
      expect(wrapper.emitted('select-branches')).toEqual([[[VALID_BRANCHES_YAML_FORMAT[1]]]]);
    });

    it('can add more branches', async () => {
      expect(findBranchSelectorModal().props('forProtectedBranches')).toBe(true);
      expect(findBranchSelectorModal().props('branches')).toEqual(VALID_BRANCHES);

      const newBranches = [
        ...VALID_BRANCHES,
        {
          fullPath: 'project',
          name: 'test3',
          value: 'test3@project_1',
        },
      ];

      findBranchSelectorModal().vm.$emit('add-branches', newBranches);
      expect(openMock).toHaveBeenCalled();

      await nextTick();

      expect(findModal().props('visible')).toBe(false);

      findDropdown().vm.$emit('hidden');
      expect(closeMock).toHaveBeenCalled();

      const expected = [
        ...VALID_BRANCHES_YAML_FORMAT,
        {
          full_path: 'project',
          name: 'test3',
        },
      ];

      expect(wrapper.emitted('select-branches')[0]).toEqual([expected]);
    });
  });

  describe('regular branches', () => {
    it('renders modal for regular branches for execution policy', () => {
      jest.spyOn(urlUtils, 'getParameterValues').mockReturnValue([SCAN_EXECUTION_POLICY_TYPE]);
      createComponent();

      expect(findBranchSelectorModal().props('forProtectedBranches')).toBe(false);
    });
  });
});
