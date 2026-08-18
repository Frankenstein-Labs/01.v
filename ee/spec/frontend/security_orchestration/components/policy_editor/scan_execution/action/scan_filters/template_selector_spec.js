import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import {
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_SAST,
} from '~/vue_shared/security_reports/constants';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import TemplateSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/template_selector.vue';
import {
  DEFAULT_TEMPLATE,
  LATEST_TEMPLATE,
  VERSIONED_TEMPLATES,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/constants';

describe('TemplateSelector', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(TemplateSelector, {
      propsData,
      stubs: {
        SectionLayout,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findIcon = () => wrapper.findComponent(HelpIcon);

  it('renders default value', () => {
    createComponent();
    expect(findDropdown().props('selected')).toBe(DEFAULT_TEMPLATE);
  });

  it('renders help icon for default template', () => {
    createComponent();
    expect(findIcon().exists()).toBe(true);
    expect(findIcon().attributes('title')).toBe(
      'CI/CD template edition to be enforced. The default template is stable, but may not have all the features of the latest template.',
    );
  });

  it('renders help icon for latest template', () => {
    createComponent({ selected: LATEST_TEMPLATE });
    expect(findIcon().exists()).toBe(true);
    expect(findIcon().attributes('title')).toBe(
      'CI/CD template edition to be enforced. The latest edition may introduce breaking changes.',
    );
  });

  it('renders selected value', () => {
    createComponent({ selected: LATEST_TEMPLATE });
    expect(findDropdown().props('selected')).toBe(LATEST_TEMPLATE);
  });

  it('emits "input" event when "latest" is selected', () => {
    createComponent();
    expect(wrapper.emitted('input')).toEqual(undefined);
    expect(wrapper.emitted('remove')).toEqual(undefined);
    findDropdown().vm.$emit('select', LATEST_TEMPLATE);
    expect(wrapper.emitted('input')).toEqual([[{ template: LATEST_TEMPLATE }]]);
    expect(wrapper.emitted('remove')).toEqual(undefined);
  });

  it('emits "remove" event when "default" is selected', () => {
    createComponent();
    expect(wrapper.emitted('input')).toEqual(undefined);
    expect(wrapper.emitted('remove')).toEqual(undefined);
    findDropdown().vm.$emit('select', LATEST_TEMPLATE);
    expect(wrapper.emitted('input')).toHaveLength(1);
    expect(wrapper.emitted('remove')).toEqual(undefined);
    findDropdown().vm.$emit('select', DEFAULT_TEMPLATE);
    expect(wrapper.emitted('input')).toHaveLength(1);
    expect(wrapper.emitted('remove')).toEqual([[]]);
  });

  describe('with versioned templates', () => {
    it('shows standard options for non-versioned scan types', () => {
      createComponent({ scanType: REPORT_TYPE_SAST });

      expect(findDropdown().props('items')).toEqual([
        { text: 'latest', value: LATEST_TEMPLATE },
        { text: 'default', value: DEFAULT_TEMPLATE },
      ]);
    });

    it('shows versioned options for dependency_scanning', () => {
      createComponent({ scanType: REPORT_TYPE_DEPENDENCY_SCANNING });

      expect(findDropdown().props('items')).toEqual(
        VERSIONED_TEMPLATES[REPORT_TYPE_DEPENDENCY_SCANNING],
      );
    });

    it('emits input event when a versioned template is selected', () => {
      createComponent({ scanType: REPORT_TYPE_DEPENDENCY_SCANNING });

      findDropdown().vm.$emit('select', 'v2');

      expect(wrapper.emitted('input')).toEqual([[{ template: 'v2' }]]);
    });

    it('shows versioned template tooltip for versioned templates', () => {
      createComponent({
        scanType: REPORT_TYPE_DEPENDENCY_SCANNING,
        selected: 'v2',
      });

      expect(findIcon().attributes('title')).toBe(
        'CI/CD template version to be enforced. Specific versions offer stability but may not include the latest features.',
      );
    });
  });
});
