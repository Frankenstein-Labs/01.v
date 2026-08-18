import { GlFormRadioGroup, GlFormRadio } from '@gitlab/ui';
import EnrichmentDataSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/enrichment_data_settings.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  ENRICHMENT_DATA_ACTIONS,
  ENRICHMENT_DATA_ACTION_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('EnrichmentDataSettings', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(EnrichmentDataSettings, {
      propsData,
    });
  };

  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findRadioItems = () => wrapper.findAllComponents(GlFormRadio);
  const findPopovers = () => wrapper.findAllComponents(PolicyPopover);
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findHeader = () => wrapper.find('h5');

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the header with correct text', () => {
      expect(findHeader().exists()).toBe(true);
      expect(findHeader().text()).toBe('Exception settings');
    });

    it('renders the section layout without remove button', () => {
      expect(findSectionLayout().exists()).toBe(true);
      expect(findSectionLayout().props('showRemoveButton')).toBe(false);
    });

    it('renders radio group with block selected by default', () => {
      expect(findRadioGroup().exists()).toBe(true);
      expect(findRadioGroup().props('checked')).toBe(ENRICHMENT_DATA_ACTIONS.BLOCK);
    });

    it('renders individual radio items for each option', () => {
      expect(findRadioItems()).toHaveLength(ENRICHMENT_DATA_ACTION_OPTIONS.length);
      expect(findRadioItems().at(0).props('value')).toBe(ENRICHMENT_DATA_ACTIONS.BLOCK);
      expect(findRadioItems().at(1).props('value')).toBe(ENRICHMENT_DATA_ACTIONS.IGNORE);
    });

    it('renders a policy popover for each radio option', () => {
      const popovers = findPopovers();

      expect(popovers).toHaveLength(ENRICHMENT_DATA_ACTION_OPTIONS.length);

      ENRICHMENT_DATA_ACTION_OPTIONS.forEach((option, index) => {
        expect(popovers.at(index).props('content')).toBe(option.popoverContent);
        expect(popovers.at(index).props('title')).toBe(option.text);
        expect(popovers.at(index).props('target')).toBe(`enrichment-data-${option.value}-icon`);
      });
    });
  });

  describe('with block action selected', () => {
    beforeEach(() => {
      createComponent({
        propsData: { selectedAction: ENRICHMENT_DATA_ACTIONS.BLOCK },
      });
    });

    it('renders radio group with block checked', () => {
      expect(findRadioGroup().props('checked')).toBe(ENRICHMENT_DATA_ACTIONS.BLOCK);
    });
  });

  describe('with ignore action selected', () => {
    beforeEach(() => {
      createComponent({
        propsData: { selectedAction: ENRICHMENT_DATA_ACTIONS.IGNORE },
      });
    });

    it('renders radio group with ignore checked', () => {
      expect(findRadioGroup().props('checked')).toBe(ENRICHMENT_DATA_ACTIONS.IGNORE);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits change event with ignore when radio changes to ignore', () => {
      findRadioGroup().vm.$emit('change', ENRICHMENT_DATA_ACTIONS.IGNORE);

      expect(wrapper.emitted('change')).toEqual([[ENRICHMENT_DATA_ACTIONS.IGNORE]]);
    });

    it('emits change event with block when radio changes to block', () => {
      findRadioGroup().vm.$emit('change', ENRICHMENT_DATA_ACTIONS.BLOCK);

      expect(wrapper.emitted('change')).toEqual([[ENRICHMENT_DATA_ACTIONS.BLOCK]]);
    });
  });

  describe('radio options', () => {
    beforeEach(() => {
      createComponent();
    });

    it('provides correct radio options from constants', () => {
      const radioItems = findRadioItems();

      expect(radioItems).toHaveLength(2);
      expect(radioItems.at(0).props('value')).toBe(ENRICHMENT_DATA_ACTIONS.BLOCK);
      expect(radioItems.at(1).props('value')).toBe(ENRICHMENT_DATA_ACTIONS.IGNORE);
    });
  });
});
