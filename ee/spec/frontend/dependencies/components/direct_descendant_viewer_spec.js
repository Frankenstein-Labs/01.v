import { shallowMount } from '@vue/test-utils';
import { GlIntersperse } from '@gitlab/ui';
import DirectDescendantViewer from 'ee/dependencies/components/direct_descendant_viewer.vue';

describe('DirectDescendantViewer component', () => {
  let wrapper;

  const factory = (options = {}) => {
    wrapper = shallowMount(DirectDescendantViewer, {
      ...options,
      stubs: {
        GlIntersperse,
      },
    });
  };

  it.each`
    dependencies                                                                  | path
    ${[]}                                                                         | ${''}
    ${[{ name: 'emmajsq' }]}                                                      | ${'emmajsq'}
    ${[{ name: 'emmajsq', version: '10.11' }]}                                    | ${'emmajsq 10.11'}
    ${[{ name: 'emmajsq' }, { name: 'swell' }]}                                   | ${'emmajsq / swell'}
    ${[{ name: 'emmajsq', version: '10.11' }, { name: 'swell', version: '1.2' }]} | ${'emmajsq 10.11 / swell 1.2'}
  `('shows complete direct descendant path for $path', ({ dependencies, path }) => {
    factory({
      propsData: { dependencies },
    });

    expect(wrapper.text()).toBe(path);
  });
});
