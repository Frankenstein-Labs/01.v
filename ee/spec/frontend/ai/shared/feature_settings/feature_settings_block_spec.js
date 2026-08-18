import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';

describe('FeatureSettingsBlock', () => {
  let wrapper;
  const MOCK_ID = 'feature-settings-block-id';
  const MOCK_TITLE = 'Feature Settings Block Title';
  const MOCK_SLOT_DESCRIPTION = '<p data-testid="slot-description">Slot description</p>';
  const MOCK_SLOT_CONTENT = '<div data-testid="slot-content">Slot content</div>';

  const createComponent = () => {
    wrapper = shallowMountExtended(FeatureSettingsBlock, {
      propsData: {
        id: MOCK_ID,
        title: MOCK_TITLE,
      },
      scopedSlots: {
        description: MOCK_SLOT_DESCRIPTION,
        content: MOCK_SLOT_CONTENT,
      },
    });
  };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);

  beforeEach(() => {
    createComponent();
  });

  it('renders settings block', () => {
    const settingsBlock = findSettingsBlock();
    expect(settingsBlock.props()).toEqual({
      id: MOCK_ID,
      title: MOCK_TITLE,
      expanded: true,
    });
  });

  it('renders description slot', () => {
    expect(wrapper.findByTestId('slot-description').html()).toBe(MOCK_SLOT_DESCRIPTION);
  });

  it('renders content slot', () => {
    expect(wrapper.findByTestId('slot-content').html()).toBe(MOCK_SLOT_CONTENT);
  });

  describe('toggle state', () => {
    it('is in expanded state when the component is first rendered', () => {
      expect(findSettingsBlock().props('expanded')).toBe(true);
    });

    it('correctly updates toggle state', async () => {
      findSettingsBlock().vm.$emit('toggle-expand', false);
      await nextTick();

      expect(findSettingsBlock().props('expanded')).toBe(false);
    });
  });
});
