import { GlSprintf, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import BranchSelector from 'ee/security_orchestration/components/policy_editor/branch_selector.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import {
  NO_EXCEPTION_KEY,
  EXCEPTION_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';

describe('BranchExceptionSelector', () => {
  let wrapper;

  const MOCK_BRANCHES = ['main', 'test'];

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(BranchExceptionSelector, {
      propsData,
      stubs: {
        GlSprintf: stubComponent(GlSprintf, {
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findBranchSelector = () => wrapper.findComponent(BranchSelector);
  const findNamespaceTypeListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default rendering states', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should display branches listbox for exceptions', async () => {
      await findNamespaceTypeListbox().vm.$emit('select', EXCEPTION_KEY);
      expect(findBranchSelector().exists()).toBe(true);
    });
  });

  describe('existing branch exceptions', () => {
    it('should display saved exceptions', () => {
      createComponent({
        propsData: { selectedExceptions: MOCK_BRANCHES },
      });

      expect(findBranchSelector().props('selectedExceptions')).toEqual(MOCK_BRANCHES);
    });
  });

  describe('exception selection', () => {
    it('should select exceptions', async () => {
      createComponent();

      await findNamespaceTypeListbox().vm.$emit('select', EXCEPTION_KEY);

      await findBranchSelector().vm.$emit('select-branches', MOCK_BRANCHES);

      expect(wrapper.emitted('select')).toEqual([[{ branch_exceptions: MOCK_BRANCHES }]]);
    });
  });

  describe('no exceptions', () => {
    it('should reset exceptions when type is changed', () => {
      createComponent({
        propsData: { selectedExceptions: MOCK_BRANCHES },
      });

      findNamespaceTypeListbox().vm.$emit('select', NO_EXCEPTION_KEY);

      expect(wrapper.emitted('remove')).toHaveLength(1);

      findNamespaceTypeListbox().vm.$emit('select', EXCEPTION_KEY);

      expect(wrapper.emitted('remove')).toHaveLength(1);

      findNamespaceTypeListbox().vm.$emit('select', NO_EXCEPTION_KEY);

      expect(wrapper.emitted('remove')).toHaveLength(2);
    });
  });
});
