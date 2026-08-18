import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HeaderMergeTrainsLink from 'ee/ci/pipeline_details/header/components/header_merge_trains_link.vue';

describe('Pipeline header merge trains link', () => {
  let wrapper;

  const findMergeTrainsLink = () => wrapper.findComponent(GlLink);

  const defaultProvideOptions = {
    mergeTrainsAvailable: true,
    mergeTrainsPath: '/namespace/my-project/-/merge_trains',
    canReadMergeTrain: true,
  };

  const createComponent = (provideOptions) => {
    wrapper = shallowMountExtended(HeaderMergeTrainsLink, {
      provide: { ...defaultProvideOptions, ...provideOptions },
    });
  };

  it('should display the link', () => {
    createComponent();

    expect(findMergeTrainsLink().attributes('href')).toBe(defaultProvideOptions.mergeTrainsPath);
  });

  it('should not display the link', () => {
    createComponent({ canReadMergeTrain: false, mergeTrainsAvailable: false });

    expect(findMergeTrainsLink().exists()).toBe(false);
  });
});
