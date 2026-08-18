import { GlCard, GlCollapsibleListbox, GlLink, GlIcon, GlToast } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { provideMock } from 'jest/security_configuration/mock_data';
import SetLicenseConfigurationSource from '~/security_configuration/graphql/set_license_configuration_source.graphql';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import LicenseInformationSourceFeatureCard from 'ee/security_configuration/components/license_information_source_feature_card.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { LICENSE_INFORMATION_SOURCE } from '~/security_configuration/constants';

Vue.use(VueApollo);
Vue.use(GlToast);

const setMockResponse = {
  data: {
    setLicenseConfigurationSource: {
      licenseConfigurationSource: 'PMDB',
      errors: [],
    },
  },
};
const feature = {
  name: 'License Information Source',
  description: 'Description',
  type: LICENSE_INFORMATION_SOURCE,
  available: true,
  configured: true,
  canUserConfigure: true,
};

describe('LicenseInformationSourceFeatureCard component', () => {
  let wrapper;
  let apolloProvider;
  let requestHandlers;

  const createMockApolloProvider = () => {
    requestHandlers = {
      setMutationHandler: jest.fn().mockResolvedValue(setMockResponse),
    };
    return createMockApollo([[SetLicenseConfigurationSource, requestHandlers.setMutationHandler]]);
  };

  const createComponent = ({ props = {} } = {}) => {
    apolloProvider = createMockApolloProvider();

    wrapper = extendedWrapper(
      shallowMount(LicenseInformationSourceFeatureCard, {
        propsData: {
          feature,
          ...props,
        },
        provide: provideMock,
        apolloProvider,
        stubs: {
          GlCard,
          GlCollapsibleListbox,
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

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findListboxTooltip = () => wrapper.findByTestId('license-source-listbox-tooltip');
  const findLink = () => wrapper.findComponent(GlLink);
  const findLockIcon = () => wrapper.findComponent(GlIcon);

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
    it('renders listbox in correct default state -- SBOM', () => {
      expect(findListbox().props('disabled')).toBe(false);
      expect(findListbox().props('selected')).toBe('SBOM');
    });

    it('renders lock icon', () => {
      expect(findLockIcon().exists()).toBe(true);
    });

    it('calls mutation on listbox change with correct payload', async () => {
      expect(findListbox().props('selected')).toBe('SBOM');
      findListbox().vm.$emit('select', 'PMDB');

      expect(requestHandlers.setMutationHandler).toHaveBeenCalledWith({
        input: {
          projectPath: provideMock.projectFullPath,
          source: 'PMDB',
        },
      });

      await waitForPromises();

      expect(findListbox().props('selected')).toBe('PMDB');
      expect(wrapper.text()).toContain('PMDB');
    });

    describe('when user cannot configure', () => {
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

      it('renders disabled listbox', () => {
        expect(findListbox().props('disabled')).toBe(true);
      });

      it('shows a tooltip explaining why the listbox is disabled', () => {
        expect(findListboxTooltip().attributes('title')).toBe(
          'Only security managers, maintainers, and owners can toggle this feature.',
        );
      });
    });

    describe('when user can configure', () => {
      it('does not show a tooltip', () => {
        expect(findListboxTooltip().attributes('title')).toBeUndefined();
      });
    });
  });

  describe('when feature is not availabe', () => {
    describe('license configuration source is disabled', () => {
      beforeEach(() => {
        createComponent({
          props: {
            feature: {
              ...feature,
              configured: false,
            },
          },
        });
      });

      it('renders the should disable listbox when feature is not configured', () => {
        expect(wrapper.text()).toContain('Not enabled');
      });

      it('does not render lock icon', () => {
        expect(findLockIcon().exists()).toBe(false);
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

      it('should not render listbox', () => {
        expect(findListbox().exists()).toBe(false);
      });

      it('should not render lock icon', () => {
        expect(findLockIcon().exists()).toBe(false);
      });
    });
  });
});
