import { shallowMount } from '@vue/test-utils';
import { GlTab, GlTabs } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import GroupConfigurationTabs from 'ee/security_configuration/components/group_configuration_tabs.vue';
import GroupScannersOverview from 'ee/security_configuration/components/scan_profiles/group_scanners_overview.vue';
import ConfigureAttributes from 'ee/security_configuration/components/security_attributes/configure_attributes.vue';

describe('GroupConfigurationTabs', () => {
  let wrapper;

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMount(GroupConfigurationTabs, {
      stubs: { GlTab },
      provide: {
        canManageAttributes: false,
        canReadScanProfiles: false,
        ...provide,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findGroupScannersOverview = () => wrapper.findComponent(GroupScannersOverview);
  const findConfigureAttributes = () => wrapper.findComponent(ConfigureAttributes);

  it('renders the "Security configuration" page heading', () => {
    createComponent();

    expect(findPageHeading().props('heading')).toBe('Security configuration');
  });

  describe('tab query-param syncing', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          canManageAttributes: true,
          canReadScanProfiles: true,
        },
      });
    });

    it('syncs the active tab with the "tab" query param', () => {
      expect(findTabs().props('syncActiveTabWithQueryParams')).toBe(true);
      expect(findTabs().props('queryParamName')).toBe('tab');
    });

    it('exposes "scanners" and "attributes" as deep-link tab values', () => {
      const values = findAllTabs().wrappers.map((tab) => tab.props('queryParamValue'));
      expect(values).toEqual(['scanners', 'attributes']);
    });
  });

  describe('Scanners tab', () => {
    it('renders GroupScannersOverview when canReadScanProfiles is true', () => {
      createComponent({
        provide: {
          canReadScanProfiles: true,
        },
      });

      expect(findGroupScannersOverview().exists()).toBe(true);
    });

    it('does not render GroupScannersOverview when canReadScanProfiles is false', () => {
      createComponent();

      expect(findGroupScannersOverview().exists()).toBe(false);
    });
  });

  describe('Security attributes tab', () => {
    it('renders ConfigureAttributes and the tab description when canManageAttributes is true', () => {
      createComponent({ provide: { canManageAttributes: true } });

      expect(findConfigureAttributes().exists()).toBe(true);
    });

    it('does not render the Security attributes tab when canManageAttributes is false', () => {
      createComponent();

      expect(findConfigureAttributes().exists()).toBe(false);
    });
  });
});
