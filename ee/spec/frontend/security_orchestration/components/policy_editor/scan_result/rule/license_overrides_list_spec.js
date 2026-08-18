import { shallowMount } from '@vue/test-utils';
import LicenseOverridesList from 'ee/security_orchestration/components/policy_editor/scan_result/rule/license_overrides_list.vue';
import LicenseOverridesModal from 'ee/security_orchestration/components/policy_editor/scan_result/rule/license_overrides_modal.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';

describe('LicenseOverridesList', () => {
  let wrapper;

  const mockOverrides = [
    { purl: 'pkg:pypi/urllib3', license: 'MIT License', mode: 'patch' },
    { purl: 'pkg:gem/rails', license: 'Apache-2.0', mode: 'overwrite' },
  ];

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(LicenseOverridesList, {
      propsData: {
        overrides: [],
        ...props,
      },
    });
  };

  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findModal = () => wrapper.findComponent(LicenseOverridesModal);

  describe('default state (no overrides)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders section layout with correct label', () => {
      expect(findSectionLayout().exists()).toBe(true);
      expect(findSectionLayout().props('ruleLabel')).toBe('License Overrides:');
    });

    it('renders the modal', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('displays zero count in button text', () => {
      expect(wrapper.text()).toContain('0');
    });

    it('passes empty overrides to modal', () => {
      expect(findModal().props('overrides')).toEqual([]);
    });
  });

  describe('with overrides', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
    });

    it('displays the override count in button text', () => {
      expect(wrapper.text()).toContain('2');
    });

    it('passes overrides to modal', () => {
      expect(findModal().props('overrides')).toEqual(mockOverrides);
    });
  });

  describe('interactions', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
    });

    it('emits remove when section layout emits remove', () => {
      findSectionLayout().vm.$emit('remove');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });

    it('emits update when modal saves', () => {
      const updatedOverrides = [{ purl: 'pkg:npm/lodash', license: 'MIT', mode: 'patch' }];

      findModal().vm.$emit('save', updatedOverrides);

      expect(wrapper.emitted('update')).toEqual([[updatedOverrides]]);
    });
  });
});
