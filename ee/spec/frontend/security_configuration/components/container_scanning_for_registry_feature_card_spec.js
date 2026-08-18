import { GlCard, GlToggle, GlLink, GlIcon, GlPopover, GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import SetContainerScanningForRegistry from 'ee/security_configuration/graphql/set_container_scanning_for_registry.mutation.graphql';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import ContainerScanningForRegistryFeatureCard from 'ee_component/security_configuration/components/container_scanning_for_registry_feature_card.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY } from '~/vue_shared/security_reports/constants';

Vue.use(VueApollo);
Vue.use(GlToast);

const setMockResponse = {
  data: {
    setContainerScanningForRegistry: {
      containerScanningForRegistryEnabled: true,
      errors: [],
    },
  },
};
const feature = {
  name: 'Container Scanning for Registry',
  description: 'Description',
  type: REPORT_TYPE_CONTAINER_SCANNING_FOR_REGISTRY,
  available: true,
  configured: false,
  canUserConfigure: true,
};

const defaultProvide = {
  userIsProjectAdmin: true,
  projectFullPath: 'flightjs/flight',
};

describe('ContainerScanningForRegistryFeatureCard component', () => {
  let wrapper;
  let apolloProvider;
  let requestHandlers;

  const createMockApolloProvider = () => {
    requestHandlers = {
      setMutationHandler: jest.fn().mockResolvedValue(setMockResponse),
    };
    return createMockApollo([
      [SetContainerScanningForRegistry, requestHandlers.setMutationHandler],
    ]);
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    apolloProvider = createMockApolloProvider();

    wrapper = extendedWrapper(
      shallowMount(ContainerScanningForRegistryFeatureCard, {
        propsData: {
          feature,
          ...props,
        },
        provide: {
          ...defaultProvide,
          ...provide,
        },
        apolloProvider,
        mocks: {
          $toast: {
            show: jest.fn(),
          },
        },
        stubs: {
          GlCard,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    apolloProvider = null;
  });

  const findToggle = () => wrapper.findComponent(GlToggle);
  const findLink = () => wrapper.findComponent(GlLink);
  const findLockIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);

  it('renders correct name and description', () => {
    expect(wrapper.text()).toContain(feature.name);
    expect(wrapper.text()).toContain(feature.description);
  });

  it('shows the help link', () => {
    const link = findLink();
    expect(link.text()).toBe('Learn more.');
    expect(link.attributes('href')).toBe(feature.helpPath);
  });

  describe('when feature is available', () => {
    beforeEach(() => {
      createComponent();
    });
    it('renders toggle in correct default state', () => {
      expect(findToggle().props('disabled')).toBe(false);
      expect(findToggle().props('value')).toBe(false);
    });

    it('does not render lock icon', () => {
      expect(findLockIcon().exists()).toBe(false);
    });

    it('does not render popover', () => {
      expect(findPopover().exists()).toBe(false);
    });

    it('calls mutation on toggle change with correct payload', async () => {
      expect(findToggle().props('value')).toBe(false);
      findToggle().vm.$emit('change', true);

      expect(requestHandlers.setMutationHandler).toHaveBeenCalledWith({
        input: {
          namespacePath: defaultProvide.projectFullPath,
          enable: true,
        },
      });

      await waitForPromises();

      expect(findToggle().props('value')).toBe(true);
      expect(wrapper.text()).toContain('Enabled');
    });
  });

  describe('when feature is not availabe', () => {
    describe('container scanning for registry is disabled', () => {
      beforeEach(() => {
        createComponent({
          props: {
            feature: {
              ...feature,
              canUserConfigure: false,
            },
          },
        });
      });

      it('should disable toggle when feature is not configured', () => {
        expect(findToggle().props('disabled')).toBe(true);
      });

      it('renders lock icon', () => {
        expect(findLockIcon().exists()).toBe(true);
        expect(findLockIcon().props('name')).toBe('lock');
      });

      it('renders popover', () => {
        expect(findPopover().exists()).toBe(true);
      });

      it('shows correct tooltip', () => {
        expect(findPopover().text()).toBe(
          'Only security managers, maintainers, and owners can toggle this feature.',
        );
      });
    });

    describe('when feature is not available with current license', () => {
      beforeEach(() => {
        createComponent({
          props: {
            feature: {
              ...feature,
              available: false,
            },
          },
        });
      });
      it('should display correct message', () => {
        expect(wrapper.text()).toContain('Available with Ultimate');
      });

      it('should not render toggle', () => {
        expect(findToggle().exists()).toBe(false);
      });

      it('should not render lock icon', () => {
        expect(findLockIcon().exists()).toBe(false);
      });
    });
  });
});
