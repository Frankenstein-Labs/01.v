import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ComplianceViolationStatusDropdown from 'ee/vue_shared/compliance/components/violation_status_dropdown/compliance_violation_status_dropdown.vue';
import { COMPLIANCE_STATUS_OPTIONS } from 'ee/vue_shared/compliance/constants';

describe('ComplianceViolationStatusDropdown', () => {
  let wrapper;

  const defaultProps = {
    value: 'detected',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(ComplianceViolationStatusDropdown, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the GlCollapsibleListbox component', () => {
      expect(findListbox().exists()).toBe(true);
    });

    it('passes the correct props to GlCollapsibleListbox', () => {
      const listbox = findListbox();

      expect(listbox.props()).toMatchObject({
        items: COMPLIANCE_STATUS_OPTIONS,
        selected: 'detected',
        toggleText: 'Detected',
        disabled: false,
        loading: false,
        variant: 'link',
      });
    });
  });

  describe('props validation', () => {
    it('validates value prop correctly', () => {
      const { validator } = ComplianceViolationStatusDropdown.props.value;

      expect(validator('detected')).toBe(true);
      expect(validator('dismissed')).toBe(true);
      expect(validator('in_review')).toBe(true);
      expect(validator('resolved')).toBe(true);
      expect(validator('invalid_status')).toBe(false);
    });
  });

  describe('when disabled', () => {
    beforeEach(() => {
      createComponent({ disabled: true });
    });

    it('passes disabled prop to GlCollapsibleListbox', () => {
      expect(findListbox().props('disabled')).toBe(true);
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ loading: true });
    });

    it('passes loading prop to GlCollapsibleListbox', () => {
      expect(findListbox().props('loading')).toBe(true);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits change event when a different value is selected', () => {
      findListbox().vm.$emit('select', 'dismissed');

      expect(wrapper.emitted('change')).toEqual([['dismissed']]);
    });

    it('does not emit change event when the same value is selected', () => {
      findListbox().vm.$emit('select', 'detected');

      expect(wrapper.emitted('change')).toBeUndefined();
    });
  });

  describe('handleSelect method', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls handleSelect when listbox emits select event', () => {
      findListbox().vm.$emit('select', 'in_review');

      expect(wrapper.emitted('change')).toEqual([['in_review']]);
    });
  });
});
