import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FeatureCard from 'ee/groups/discover/components/feature_card.vue';
import FeatureItem from 'ee/groups/discover/components/feature_item.vue';

describe('FeatureCard', () => {
  let wrapper;

  const defaultProps = {
    topHeader: 'Top Header',
    bottomHeader: 'Bottom Header',
    items: [
      { id: '1', text: 'Feature 1', description: 'Description 1' },
      { id: '2', text: 'Feature 2', description: 'Description 2' },
    ],
    handlePopoverToggle: jest.fn(),
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(FeatureCard, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders top header', () => {
    expect(wrapper.text()).toContain('Top Header');
  });

  it('renders bottom header', () => {
    expect(wrapper.text()).toContain('Bottom Header');
  });

  it('renders feature items for each item in props', () => {
    expect(wrapper.findAllComponents(FeatureItem)).toHaveLength(2);
  });

  it('passes correct props to feature items', () => {
    const featureItems = wrapper.findAllComponents(FeatureItem);

    expect(featureItems.at(0).props()).toMatchObject({
      id: '1',
      text: 'Feature 1',
      description: 'Description 1',
    });

    expect(featureItems.at(1).props()).toMatchObject({
      id: '2',
      text: 'Feature 2',
      description: 'Description 2',
    });
  });

  it('forwards popover-toggle event from feature items', async () => {
    const featureItems = wrapper.findAllComponents(FeatureItem);

    await featureItems.at(0).vm.$emit('popover-toggle', '1');

    expect(defaultProps.handlePopoverToggle).toHaveBeenCalledWith('1');
  });

  it('passes openPopoverId to feature items', async () => {
    await wrapper.setProps({ openPopoverId: '1' });

    const featureItems = wrapper.findAllComponents(FeatureItem);
    expect(featureItems.at(0).props('openPopoverId')).toBe('1');
  });
});
