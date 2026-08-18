import { GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ReadOnlyProjectBadge from 'ee/usage_quotas/storage/namespace/components/read_only_project_badge.vue';

describe('ReadOnlyProjectBadge', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const defaultProps = {
    namespace: {
      actualRepositorySizeLimit: 1000,
    },
    project: {
      statistics: {
        repositorySize: '500',
        lfsObjectsSize: '400',
      },
    },
  };

  const createComponent = (props = {}, provide = {}) => {
    wrapper = shallowMountExtended(ReadOnlyProjectBadge, {
      provide: {
        aboveSizeLimit: true,
        ...provide,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  it('renders badge when project is above the size limit', () => {
    createComponent({
      namespace: { actualRepositorySizeLimit: 800 },
    });

    expect(wrapper.findComponent(GlBadge).text()).toBe('read-only');
  });

  it('does not render badge when project is not above the size limit', () => {
    createComponent();

    expect(wrapper.findComponent(GlBadge).exists()).toBe(false);
  });

  it('does not render badge when group is not above the size limit', () => {
    createComponent({
      aboveSizeLimit: false,
    });

    expect(wrapper.findComponent(GlBadge).exists()).toBe(false);
  });
});
