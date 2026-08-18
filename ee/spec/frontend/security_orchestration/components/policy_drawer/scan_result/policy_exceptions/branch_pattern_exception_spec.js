import { GlAccordion, GlAccordionItem, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchPatternException from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/branch_pattern_exception.vue';

describe('BranchPatternException', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(BranchPatternException, {
      propsData,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findBranchItems = () => wrapper.findAllByTestId('branch-item');

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders accordion with correct header level', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAccordion().props('headerLevel')).toBe(3);
      expect(findAccordionItem().props('title')).toBe('Branch exceptions (0)');
    });

    it('does not render any branch items when branches array is empty', () => {
      expect(findBranchItems()).toHaveLength(0);
    });
  });

  describe('with valid branches', () => {
    const mockBranches = [
      {
        source: { pattern: 'feature/*' },
        target: { name: 'main' },
      },
      {
        source: { pattern: 'hotfix/*' },
        target: { name: 'release' },
      },
    ];

    beforeEach(() => {
      createComponent({
        propsData: {
          branches: mockBranches,
        },
      });
    });

    it('displays correct count in title', () => {
      expect(findAccordionItem().props('title')).toBe('Branch exceptions (2)');
    });

    it('renders branch items for each valid branch', () => {
      expect(findBranchItems()).toHaveLength(2);
    });

    it('passes correct message to GlSprintf components', () => {
      const branchItems = findBranchItems();

      expect(branchItems.at(0).text()).toBe('From feature/* to: main');
      expect(branchItems.at(1).text()).toBe('From hotfix/* to: release');
    });
  });

  describe('with invalid branches', () => {
    const mockInvalidBranches = [
      {
        source: { pattern: 'feature/*' },
        // missing target.name
      },
      {
        // missing source.pattern
        target: { name: 'main' },
      },
      {
        source: { pattern: '' },
        target: { name: 'main' },
      },
      {
        source: { pattern: 'feature/*' },
        target: { name: '' },
      },
    ];

    beforeEach(() => {
      createComponent({
        propsData: {
          branches: mockInvalidBranches,
        },
      });
    });

    it('filters out invalid branches and shows correct count', () => {
      expect(findAccordionItem().props('title')).toBe('Branch exceptions (0)');
      expect(findBranchItems()).toHaveLength(0);
    });
  });

  describe('with mixed valid and invalid branches', () => {
    const mockMixedBranches = [
      {
        source: { pattern: 'feature/*' },
        target: { name: 'main' },
      },
      {
        source: { pattern: '' },
        target: { name: 'main' },
      },
      {
        source: { pattern: 'hotfix/*' },
        target: { name: 'release' },
      },
    ];

    beforeEach(() => {
      createComponent({
        propsData: {
          branches: mockMixedBranches,
        },
      });
    });

    it('only counts and renders valid branches', () => {
      expect(findAccordionItem().props('title')).toBe('Branch exceptions (2)');
      expect(findBranchItems()).toHaveLength(2);
    });
  });

  describe('with target.pattern (new format)', () => {
    const mockBranchesWithPattern = [
      {
        source: { pattern: 'feature/*' },
        target: { pattern: 'main' },
      },
      {
        source: { pattern: 'hotfix/*' },
        target: { pattern: 'release/*' },
      },
    ];

    beforeEach(() => {
      createComponent({
        propsData: {
          branches: mockBranchesWithPattern,
        },
      });
    });

    it('displays correct count in title', () => {
      expect(findAccordionItem().props('title')).toBe('Branch exceptions (2)');
    });

    it('renders branch items for each valid branch', () => {
      expect(findBranchItems()).toHaveLength(2);
    });

    it('passes correct message to GlSprintf components', () => {
      const branchItems = findBranchItems();

      expect(branchItems.at(0).text()).toBe('From feature/* to: main');
      expect(branchItems.at(1).text()).toBe('From hotfix/* to: release/*');
    });
  });

  describe('with mixed target.name and target.pattern', () => {
    const mockMixedTargetBranches = [
      {
        source: { pattern: 'feature/*' },
        target: { name: 'main' },
      },
      {
        source: { pattern: 'release/*' },
        target: { pattern: 'production' },
      },
    ];

    beforeEach(() => {
      createComponent({
        propsData: {
          branches: mockMixedTargetBranches,
        },
      });
    });

    it('handles both target.name and target.pattern', () => {
      expect(findAccordionItem().props('title')).toBe('Branch exceptions (2)');
      const branchItems = findBranchItems();
      expect(branchItems.at(0).text()).toBe('From feature/* to: main');
      expect(branchItems.at(1).text()).toBe('From release/* to: production');
    });
  });
});
