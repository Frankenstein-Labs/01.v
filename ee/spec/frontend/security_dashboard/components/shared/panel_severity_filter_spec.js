import { nextTick } from 'vue';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PanelSeverityFilter from 'ee/security_dashboard/components/shared/panel_severity_filter.vue';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filtered_search/constants';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';

const SEVERITY_OPTIONS = Object.keys(SEVERITY_LEVELS).map((key) => key.toUpperCase());

describe('PanelSeverityFilter', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(PanelSeverityFilter, {
      propsData: {
        value: [],
        ...props,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('has correct props for the listbox', () => {
    createComponent();

    expect(findListbox().props()).toMatchObject({
      block: true,
      multiple: true,
      size: 'small',
    });
  });

  it.each(SEVERITY_OPTIONS)('shows "%s" severity option', (severity) => {
    createComponent();

    const items = findListbox().props('items');

    expect(items).toHaveLength(SEVERITY_OPTIONS.length + 1); // +1 for "All severities"
    expect(items[0]).toEqual({ value: ALL_ID, text: 'All severities' });

    const severityIndex = SEVERITY_OPTIONS.indexOf(severity);
    expect(items[severityIndex + 1].value).toBe(severity); // +1 for "All severities"
  });

  it('selects "All severities" by default when the given value is empty', () => {
    createComponent({ props: { value: [] } });

    expect(findListbox().props('selected')).toEqual([ALL_ID]);
  });

  it('uses the given value when it is not empty', () => {
    const value = ['CRITICAL', 'HIGH'];

    createComponent({ props: { value } });

    expect(findListbox().props('selected')).toEqual(value);
  });

  it('shows "All severities" as toggle text when no specific severities are selected', () => {
    createComponent();

    expect(findListbox().props('toggleText')).toBe('All severities');
  });

  it('shows specific severity names when selected', () => {
    createComponent({ props: { value: ['CRITICAL'] } });

    expect(findListbox().props('toggleText')).toBe('Critical');
  });

  it.each`
    severities                               | expectedText
    ${['CRITICAL', 'HIGH']}                  | ${'Critical +1 more'}
    ${['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']} | ${'Critical +3 more'}
    ${SEVERITY_OPTIONS}                      | ${`Critical +${SEVERITY_OPTIONS.length - 1} more`}
  `(
    'shows multiple severity names with count when multiple selected',
    ({ severities, expectedText }) => {
      createComponent({ props: { value: severities } });

      expect(findListbox().props('toggleText')).toBe(expectedText);
    },
  );

  it('emits input with empty array when "All severities" is selected', async () => {
    createComponent();

    findListbox().vm.$emit('select', ['CRITICAL', 'HIGH', ALL_ID]);
    await nextTick();

    expect(wrapper.emitted('input')).toEqual([[[]]]);
  });

  it('emits input with filtered values when specific severities are selected', async () => {
    createComponent();

    const selection = ['CRITICAL', 'HIGH'];

    findListbox().vm.$emit('select', selection);
    await nextTick();

    expect(wrapper.emitted('input')).toEqual([[selection]]);
  });

  it('filters out ALL_ID from emitted values', async () => {
    createComponent();

    const selection = ['CRITICAL', ALL_ID, 'HIGH'];

    findListbox().vm.$emit('select', selection);
    await nextTick();

    expect(wrapper.emitted('input')).toEqual([[['CRITICAL', 'HIGH']]]);
  });

  it('emits input with empty array when "All severities" is selected last in the selection', async () => {
    createComponent();

    findListbox().vm.$emit('select', ['CRITICAL', ALL_ID]);
    await nextTick();

    expect(wrapper.emitted('input')).toEqual([[[]]]);
  });
});
