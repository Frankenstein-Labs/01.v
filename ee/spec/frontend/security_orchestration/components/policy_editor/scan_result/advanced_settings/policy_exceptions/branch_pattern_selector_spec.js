import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchPatternSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_selector.vue';
import BranchPatternItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/branch_pattern_item.vue';
import { mockBranchPatterns } from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

describe('BranchPatternSelector', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(BranchPatternSelector, {
      propsData: {
        patterns: [],
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findAddPatternButton = () => wrapper.findComponentByTestId('add-branch-pattern');
  const findBranchPatternItems = () => wrapper.findAllComponents(BranchPatternItem);
  const findHelpLink = () => wrapper.findComponent(GlLink);
  const findComponentHeader = () => wrapper.findByTestId('pattern-header');

  beforeEach(() => {
    createComponent();
  });

  describe('initial rendering', () => {
    it('displays the title', () => {
      expect(findComponentHeader().text()).toContain(
        'Define branch patterns that can bypass policy requirements. Use an asterisk (*) as a wildcard to match any combination of characters. Learn more',
      );
    });

    it('renders the help link with correct URL', () => {
      expect(findHelpLink().attributes('href')).toBe(
        '/help/user/project/repository/branches/protected',
      );
      expect(findHelpLink().attributes('target')).toBe('_blank');
      expect(findHelpLink().text()).toBe('Learn more');
    });

    it('creates a default pattern item when no patterns are provided', () => {
      expect(findBranchPatternItems()).toHaveLength(1);
    });

    it('renders the add pattern button with correct text', () => {
      const button = findAddPatternButton();
      expect(button.exists()).toBe(true);
      expect(button.text()).toBe('Add new criteria');
      expect(button.props()).toMatchObject({
        icon: 'plus',
        category: 'tertiary',
        variant: 'confirm',
        size: 'small',
      });
    });
  });

  describe('with provided patterns', () => {
    beforeEach(() => {
      createComponent({ branches: mockBranchPatterns });
    });

    it('maps and renders all provided patterns', () => {
      expect(findBranchPatternItems()).toHaveLength(2);
      expect(findBranchPatternItems().at(0).props('branch')).toEqual(mockBranchPatterns[0]);
      expect(findBranchPatternItems().at(1).props('branch')).toEqual(mockBranchPatterns[1]);
    });
  });

  describe('user interactions', () => {
    it('adds a new pattern when add button is clicked', async () => {
      expect(findBranchPatternItems()).toHaveLength(1);

      await findAddPatternButton().vm.$emit('click');

      expect(findBranchPatternItems()).toHaveLength(2);
    });

    it('removes a pattern when remove event is emitted', async () => {
      await findAddPatternButton().vm.$emit('click');
      expect(findBranchPatternItems()).toHaveLength(2);

      await findBranchPatternItems().at(0).vm.$emit('remove');

      expect(findBranchPatternItems()).toHaveLength(1);
    });

    it('saves selected branch patterns', async () => {
      await findBranchPatternItems().at(0).vm.$emit('set-branch', mockBranchPatterns[0]);

      expect(wrapper.emitted('set-branches')).toEqual([
        [[{ source: { pattern: 'main-*' }, target: { pattern: 'target-1' } }]],
      ]);
    });

    it('removes existing branch pattern', async () => {
      createComponent({ branches: mockBranchPatterns });

      await findBranchPatternItems().at(0).vm.$emit('remove');

      expect(wrapper.emitted('set-branches')).toEqual([
        [[{ source: { pattern: 'feature-.*' }, target: { pattern: 'target-2' } }]],
      ]);
    });
  });

  describe('duplicate validation', () => {
    const duplicateBranchPatterns = [
      {
        id: 'pattern_1',
        source: { pattern: 'feature/*' },
        target: { pattern: 'main' },
      },
      {
        id: 'pattern_2',
        source: { pattern: 'feature/*' },
        target: { pattern: 'main' },
      },
      {
        id: 'pattern_3',
        source: { pattern: 'hotfix/*' },
        target: { pattern: 'develop' },
      },
    ];

    beforeEach(() => {
      createComponent({ branches: duplicateBranchPatterns });
    });

    it('identifies duplicate branches with same source pattern and target name', () => {
      const branchPatternItems = findBranchPatternItems();

      // First two items should have validation errors (duplicates)
      expect(branchPatternItems.at(0).props('hasValidationError')).toBe(true);
      expect(branchPatternItems.at(1).props('hasValidationError')).toBe(true);

      expect(branchPatternItems.at(2).props('hasValidationError')).toBe(false);
    });

    it('passes default error message to duplicate items', () => {
      const branchPatternItems = findBranchPatternItems();

      expect(branchPatternItems.at(0).props('errorMessage')).toBe('Please remove duplicates.');
      expect(branchPatternItems.at(1).props('errorMessage')).toBe('Please remove duplicates.');
    });

    it('does not show validation error for unique branches', () => {
      const uniqueBranchPatterns = [
        {
          id: 'pattern_1',
          source: { pattern: 'feature/*' },
          target: { pattern: 'main' },
        },
        {
          id: 'pattern_2',
          source: { pattern: 'hotfix/*' },
          target: { pattern: 'develop' },
        },
      ];

      createComponent({ branches: uniqueBranchPatterns });
      const branchPatternItems = findBranchPatternItems();

      expect(branchPatternItems.at(0).props('hasValidationError')).toBe(false);
      expect(branchPatternItems.at(1).props('hasValidationError')).toBe(false);
    });

    it('handles partial duplicates correctly', () => {
      const partialDuplicateBranches = [
        {
          id: 'pattern_1',
          source: { pattern: 'feature/*' },
          target: { pattern: 'main' },
        },
        {
          id: 'pattern_2',
          source: { pattern: 'feature/*' },
          target: { pattern: 'develop' }, // Different target
        },
        {
          id: 'pattern_3',
          source: { pattern: 'hotfix/*' }, // Different source
          target: { pattern: 'main' },
        },
      ];

      createComponent({ branches: partialDuplicateBranches });
      const branchPatternItems = findBranchPatternItems();

      // None should have validation errors as they're all unique combinations
      expect(branchPatternItems.at(0).props('hasValidationError')).toBe(false);
      expect(branchPatternItems.at(1).props('hasValidationError')).toBe(false);
      expect(branchPatternItems.at(2).props('hasValidationError')).toBe(false);
    });

    it('handles empty or undefined values in duplicate detection', () => {
      const branchesWithEmptyValues = [
        {
          id: 'pattern_1',
          source: { pattern: '' },
          target: { pattern: '' },
        },
        {
          id: 'pattern_2',
          source: { pattern: '' },
          target: { pattern: '' },
        },
        {
          id: 'pattern_3',
          source: {},
          target: {},
        },
      ];

      createComponent({ branches: branchesWithEmptyValues });
      const branchPatternItems = findBranchPatternItems();

      // Items with empty values should not be treated as duplicates
      expect(branchPatternItems.at(0).props('hasValidationError')).toBe(false);
      expect(branchPatternItems.at(1).props('hasValidationError')).toBe(false);
      expect(branchPatternItems.at(2).props('hasValidationError')).toBe(false);
    });

    it('handles backward compatibility with target.name for duplicate detection', () => {
      const mixedBranchPatterns = [
        {
          id: 'pattern_1',
          source: { pattern: 'feature/*' },
          target: { name: 'main' },
        },
        {
          id: 'pattern_2',
          source: { pattern: 'feature/*' },
          target: { pattern: 'main' },
        },
      ];

      createComponent({ branches: mixedBranchPatterns });
      const branchPatternItems = findBranchPatternItems();

      expect(branchPatternItems.at(0).props('hasValidationError')).toBe(true);
      expect(branchPatternItems.at(1).props('hasValidationError')).toBe(true);
    });
  });
});
