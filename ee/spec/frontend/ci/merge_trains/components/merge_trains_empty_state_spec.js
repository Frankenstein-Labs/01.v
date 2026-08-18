import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MergeTrainsEmptyState from 'ee/ci/merge_trains/components/merge_trains_empty_state.vue';

describe('MergeTrainsEmptyState', () => {
  let wrapper;

  const projectName = 'gitlab';

  const defaultProps = {
    branch: 'feature',
  };

  const createComponent = (props = defaultProps) => {
    wrapper = shallowMount(MergeTrainsEmptyState, {
      provide: {
        projectName,
      },
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findMessage = () => wrapper.findComponent(GlSprintf);
  const findDocsLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('displays empty state', () => {
    expect(findEmptyState().exists()).toBe(true);
  });

  it('displays empty state title', () => {
    expect(findEmptyState().props('title')).toBe('No merge trains');
  });

  it('displays empty state message', () => {
    expect(findMessage().exists()).toBe(true);
  });

  it('empty state contains link to docs', () => {
    expect(findDocsLink().attributes('href')).toBe(
      '/help/ci/pipelines/merge_trains#start-a-merge-train',
    );
  });
});
