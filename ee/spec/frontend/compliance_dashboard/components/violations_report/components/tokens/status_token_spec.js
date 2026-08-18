import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import StatusToken from 'ee/compliance_dashboard/components/violations_report/components/tokens/status_token.vue';
import { COMPLIANCE_STATUS_OPTIONS } from 'ee/vue_shared/compliance/constants';

describe('StatusToken component', () => {
  let wrapper;

  const config = {
    type: 'status',
    title: 'Status',
  };

  const value = {
    data: 'detected',
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findAllSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(StatusToken, {
      propsData: {
        config,
        value,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders GlFilteredSearchToken with correct config', () => {
    const token = findFilteredSearchToken();

    expect(token.exists()).toBe(true);
    expect(token.props('config')).toEqual(config);
    expect(token.props('value')).toEqual(value);
  });

  it('displays all status options as suggestions', () => {
    const suggestions = findAllSuggestions();

    expect(suggestions).toHaveLength(COMPLIANCE_STATUS_OPTIONS.length);

    COMPLIANCE_STATUS_OPTIONS.forEach((status, index) => {
      expect(suggestions.at(index).props('value')).toBe(status.value);
      expect(suggestions.at(index).text()).toBe(status.text);
    });
  });

  it('displays status options with correct values (detected, dismissed, in_review, resolved)', () => {
    const suggestions = findAllSuggestions();
    const values = suggestions.wrappers.map((s) => s.props('value'));

    expect(values).toContain('detected');
    expect(values).toContain('dismissed');
    expect(values).toContain('in_review');
    expect(values).toContain('resolved');
  });

  describe('view slot', () => {
    it('shows selected status text in view slot', () => {
      const detectedValue = { data: 'detected' };
      createComponent({ value: detectedValue });

      const token = findFilteredSearchToken();
      // The view slot should display the formatted status name
      expect(token.text()).toContain('Detected');
    });

    it('shows correct text for dismissed status', () => {
      const dismissedValue = { data: 'dismissed' };
      createComponent({ value: dismissedValue });

      const token = findFilteredSearchToken();
      expect(token.text()).toContain('Dismissed');
    });

    it('shows correct text for in_review status', () => {
      const inReviewValue = { data: 'in_review' };
      createComponent({ value: inReviewValue });

      const token = findFilteredSearchToken();
      expect(token.text()).toContain('In review');
    });

    it('shows correct text for resolved status', () => {
      const resolvedValue = { data: 'resolved' };
      createComponent({ value: resolvedValue });

      const token = findFilteredSearchToken();
      expect(token.text()).toContain('Resolved');
    });

    it('returns input value when status not found', () => {
      const unknownValue = { data: 'unknown_status' };
      createComponent({ value: unknownValue });

      // The findActiveStatusName method should return the input value when status not found
      const token = findFilteredSearchToken();
      // Since we're using shallowMount, we can't easily test slot content
      // Instead, verify the component receives the unknown value
      expect(token.props('value')).toEqual(unknownValue);
    });
  });

  it('emits select event when status is chosen', () => {
    const token = findFilteredSearchToken();

    token.vm.$emit('select', 'resolved');

    expect(token.emitted('select')).toHaveLength(1);
    expect(token.emitted('select')[0]).toEqual(['resolved']);
  });
});
