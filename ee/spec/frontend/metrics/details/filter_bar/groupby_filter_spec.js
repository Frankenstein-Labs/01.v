import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupByFilter from 'ee/metrics/details/filter_bar/groupby_filter.vue';

describe('GroupByFilter', () => {
  let wrapper;

  const defaultProps = {
    supportedAttributes: ['attribute_one', 'attribute_two', 'attribute_three'],
    supportedFunctions: ['sum', 'avg'],
    selectedAttributes: ['attribute_one'],
    selectedFunction: 'sum',
  };

  const mount = (props = {}) => {
    wrapper = shallowMountExtended(GroupByFilter, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    mount();
  });

  const findGroupByFunctionDropdown = () =>
    wrapper.findComponentByTestId('group-by-function-dropdown');
  const findGroupByAttributesDropdown = () =>
    wrapper.findComponentByTestId('group-by-attributes-dropdown');

  it('renders the group by function dropdown', () => {
    expect(findGroupByFunctionDropdown().props('items')).toEqual([
      { value: 'sum', text: 'sum' },
      { value: 'avg', text: 'avg' },
    ]);
    expect(findGroupByFunctionDropdown().props('selected')).toEqual(defaultProps.selectedFunction);
  });

  it('renders the group by attributes dropdown in groups', () => {
    expect(findGroupByAttributesDropdown().props('items')).toEqual([
      {
        text: 'Selected dimensions',
        options: [{ value: 'attribute_one', text: 'attribute_one' }],
      },
      {
        text: 'Dimensions',
        options: [
          { value: 'attribute_two', text: 'attribute_two' },
          { value: 'attribute_three', text: 'attribute_three' },
        ],
      },
    ]);
    expect(findGroupByAttributesDropdown().props('selected')).toEqual(
      defaultProps.selectedAttributes,
    );
  });

  it('does not show the selected group if nothing is selected', () => {
    mount({ selectedAttributes: [] });

    expect(findGroupByAttributesDropdown().props('items')).toEqual([
      {
        text: 'Dimensions',
        options: [
          { value: 'attribute_one', text: 'attribute_one' },
          { value: 'attribute_two', text: 'attribute_two' },
          { value: 'attribute_three', text: 'attribute_three' },
        ],
      },
    ]);
    expect(findGroupByAttributesDropdown().props('selected')).toEqual([]);
  });

  it('does not show the attributes group if everything is selected', () => {
    mount({ selectedAttributes: [...defaultProps.supportedAttributes] });

    expect(findGroupByAttributesDropdown().props('items')).toEqual([
      {
        text: 'Selected dimensions',
        options: [
          { value: 'attribute_one', text: 'attribute_one' },
          { value: 'attribute_two', text: 'attribute_two' },
          { value: 'attribute_three', text: 'attribute_three' },
        ],
      },
    ]);
  });

  it('emits group-by on function change', async () => {
    await findGroupByFunctionDropdown().vm.$emit('select', 'avg');

    expect(wrapper.emitted('group-by')).toEqual([
      [
        {
          attributes: defaultProps.selectedAttributes,
          func: 'avg',
        },
      ],
    ]);
  });

  it('emits group-by on attribute change', async () => {
    await findGroupByAttributesDropdown().vm.$emit('select', ['attribute_two']);

    expect(wrapper.emitted('group-by')).toEqual([
      [
        {
          attributes: ['attribute_two'],
          func: defaultProps.selectedFunction,
        },
      ],
    ]);
  });

  it('updates the attributes dropdown toggle text depending on value', async () => {
    expect(findGroupByAttributesDropdown().props('toggleText')).toBe('attribute_one');

    await findGroupByAttributesDropdown().vm.$emit('select', ['attribute_two']);

    expect(findGroupByAttributesDropdown().props('toggleText')).toBe('attribute_two');

    await findGroupByAttributesDropdown().vm.$emit('select', ['attribute_two', 'attributes_one']);

    expect(findGroupByAttributesDropdown().props('toggleText')).toBe('attribute_two +1');

    await findGroupByAttributesDropdown().vm.$emit('select', [
      'attribute_two',
      'attributes_one',
      'attributes_threww',
    ]);

    expect(findGroupByAttributesDropdown().props('toggleText')).toBe('attribute_two +2');

    await findGroupByAttributesDropdown().vm.$emit('select', []);

    expect(findGroupByAttributesDropdown().props('toggleText')).toBe('Select dimensions');
  });

  it('updates the function dropdown text depending on value', async () => {
    mount({ selectedFunction: undefined });

    expect(findGroupByFunctionDropdown().props('toggleText')).toBe('Select function');

    await findGroupByFunctionDropdown().vm.$emit('select', 'avg');

    expect(findGroupByFunctionDropdown().props('toggleText')).toBe('avg');
  });
});
