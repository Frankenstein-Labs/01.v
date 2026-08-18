import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ChatLoadingState from 'ee/ai/components/chat_loading_state.vue';

describe('ChatLoadingState', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ChatLoadingState);
  };

  const findAllSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  it('renders the component', () => {
    createComponent();

    expect(wrapper.exists()).toBe(true);
  });

  it('renders skeleton loaders', () => {
    createComponent();

    expect(findAllSkeletonLoaders()).toHaveLength(8);
  });
});
