import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PlatformSelector from 'ee/ai/instance_model_selection/self_hosted_models/components/platform_selector.vue';
import { SELF_HOSTED_MODEL_PLATFORMS } from 'ee/ai/instance_model_selection/self_hosted_models/constants';

describe('PlatformSelector', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(PlatformSelector, {
      propsData: {
        platform: SELF_HOSTED_MODEL_PLATFORMS.BEDROCK,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('passes the correct props to `GlCollapsibleListbox`', () => {
    const listBox = findGlCollapsibleListbox();

    expect(listBox.props('selected')).toBe('BEDROCK');
    expect(listBox.props('toggleText')).toBe('Amazon Bedrock');
    expect(listBox.props('items')).toEqual([
      { text: 'API', value: SELF_HOSTED_MODEL_PLATFORMS.API },
      { text: 'Amazon Bedrock', value: SELF_HOSTED_MODEL_PLATFORMS.BEDROCK },
      { text: 'Google Vertex AI', value: SELF_HOSTED_MODEL_PLATFORMS.VERTEX_AI },
    ]);
  });

  it('emits an update event when the platform is changed', () => {
    findGlCollapsibleListbox().vm.$emit('select', SELF_HOSTED_MODEL_PLATFORMS.API);

    expect(wrapper.emitted('update:platform')).toEqual([[SELF_HOSTED_MODEL_PLATFORMS.API]]);
  });
});
