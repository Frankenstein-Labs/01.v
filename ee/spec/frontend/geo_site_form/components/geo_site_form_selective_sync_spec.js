import { GlFormGroup, GlSprintf, GlPopover, GlLink, GlFormSelect } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoSiteFormOrganizations from 'ee/geo_site_form/components/geo_site_form_organizations.vue';
import GeoSiteFormNamespaces from 'ee/geo_site_form/components/geo_site_form_namespaces.vue';
import GeoSiteFormSelectiveSync from 'ee/geo_site_form/components/geo_site_form_selective_sync.vue';
import GeoSiteFormShards from 'ee/geo_site_form/components/geo_site_form_shards.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { SELECTIVE_SYNC_MORE_INFO, OBJECT_STORAGE_MORE_INFO } from 'ee/geo_site_form/constants';
import {
  MOCK_SITE,
  MOCK_SELECTIVE_SYNC_TYPES,
  MOCK_SYNC_SHARDS,
  MOCK_SYNC_NAMESPACE_IDS,
} from '../mock_data';

describe('GeoSiteFormSelectiveSync', () => {
  let wrapper;

  const defaultProps = {
    siteData: MOCK_SITE,
    selectiveSyncTypes: MOCK_SELECTIVE_SYNC_TYPES,
    syncShardsOptions: MOCK_SYNC_SHARDS,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GeoSiteFormSelectiveSync, {
      stubs: { GlFormGroup, GlSprintf, HelpIcon, GlFormSelect },
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findGeoSiteFormSyncContainer = () =>
    wrapper.findComponent({ ref: 'geoSiteFormSelectiveSyncContainer' });
  const findGeoSiteFormSyncTypeFormGroup = () => wrapper.findByTestId('selective-sync-form-group');
  const findGeoSiteFormSyncTypePopoverIcon = () =>
    findGeoSiteFormSyncTypeFormGroup().findComponent(HelpIcon);
  const findGeoSiteFormSyncTypePopover = () =>
    findGeoSiteFormSyncTypeFormGroup().findComponent(GlPopover);
  const findGeoSiteFormSyncTypePopoverLink = () =>
    findGeoSiteFormSyncTypePopover().findComponent(GlLink);

  const findGeoSiteFormObjectStorageFormGroup = () =>
    wrapper.findByTestId('object-storage-form-group');
  const findGeoSiteFormObjectStoragePopoverIcon = () =>
    findGeoSiteFormObjectStorageFormGroup().findComponent(HelpIcon);
  const findGeoSiteFormObjectStoragePopover = () =>
    findGeoSiteFormObjectStorageFormGroup().findComponent(GlPopover);
  const findGeoSiteFormObjectStoragePopoverLink = () =>
    findGeoSiteFormObjectStoragePopover().findComponent(GlLink);

  const findGeoSiteFormSyncTypeField = () =>
    wrapper.findComponent('#site-selective-synchronization-field');
  const findGeoSiteFormNamespacesField = () => wrapper.findComponent(GeoSiteFormNamespaces);
  const findGeoSiteFormShardsField = () => wrapper.findComponent(GeoSiteFormShards);
  const findGeoSiteFormOrganizationsField = () => wrapper.findComponent(GeoSiteFormOrganizations);
  const findGeoSiteObjectStorageField = () => wrapper.find('#site-object-storage-field');

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders Geo Site Form Sync Container', () => {
      expect(findGeoSiteFormSyncContainer().exists()).toBe(true);
    });

    it('renders Geo Site Sync Type Field with correct props', () => {
      expect(findGeoSiteFormSyncTypeField().props()).toMatchObject({
        value: MOCK_SITE.selectiveSyncType,
        options: Object.values(MOCK_SELECTIVE_SYNC_TYPES),
      });
    });

    it('renders Geo Site Object Storage Field', () => {
      expect(findGeoSiteObjectStorageField().exists()).toBe(true);
    });

    describe('selective sync form group', () => {
      it('renders with correct text', () => {
        expect(findGeoSiteFormSyncTypeFormGroup().attributes('description')).toBe(
          'Choose specific groups, storage shards, or organizations.',
        );
      });
    });

    describe('selective sync type popover', () => {
      it('renders the question icon correctly', () => {
        expect(findGeoSiteFormSyncTypePopoverIcon().exists()).toBe(true);
        expect(findGeoSiteFormSyncTypePopoverIcon().attributes('name')).toBe('question-o');
      });

      it('renders the popover link correctly', () => {
        expect(findGeoSiteFormSyncTypePopoverLink().exists()).toBe(true);
        expect(findGeoSiteFormSyncTypePopoverLink().attributes('href')).toBe(
          SELECTIVE_SYNC_MORE_INFO,
        );
      });

      it('renders the GlPopover with correct text', () => {
        expect(findGeoSiteFormSyncTypePopover().text()).toContain(
          'Geo allows you to choose specific groups, storage shards, or organizations to replicate.',
        );
      });
    });

    describe('object storage popover', () => {
      it('renders the question icon correctly', () => {
        expect(findGeoSiteFormObjectStoragePopoverIcon().exists()).toBe(true);
        expect(findGeoSiteFormObjectStoragePopoverIcon().attributes('name')).toBe('question-o');
      });

      it('renders the GlPopover', () => {
        expect(findGeoSiteFormObjectStoragePopover().exists()).toBe(true);
        expect(findGeoSiteFormObjectStoragePopover().text()).toContain(
          GeoSiteFormSelectiveSync.i18n.objectStorageFieldPopoverText,
        );
      });

      it('renders the popover link correctly', () => {
        expect(findGeoSiteFormObjectStoragePopoverLink().exists()).toBe(true);
        expect(findGeoSiteFormObjectStoragePopoverLink().attributes('href')).toBe(
          OBJECT_STORAGE_MORE_INFO,
        );
      });
    });

    describe.each`
      syncType                                   | showNamespaces | showShards | showOrganizations
      ${MOCK_SELECTIVE_SYNC_TYPES.ALL}           | ${false}       | ${false}   | ${false}
      ${MOCK_SELECTIVE_SYNC_TYPES.NAMESPACES}    | ${true}        | ${false}   | ${false}
      ${MOCK_SELECTIVE_SYNC_TYPES.SHARDS}        | ${false}       | ${true}    | ${false}
      ${MOCK_SELECTIVE_SYNC_TYPES.ORGANIZATIONS} | ${false}       | ${false}   | ${true}
    `(`sync type`, ({ syncType, showNamespaces, showShards, showOrganizations }) => {
      beforeEach(() => {
        createComponent({
          siteData: { ...defaultProps.siteData, selectiveSyncType: syncType.value },
        });
      });

      it(`${showNamespaces ? 'show' : 'hide'} Namespaces Field`, () => {
        expect(findGeoSiteFormNamespacesField().exists()).toBe(showNamespaces);
      });

      it(`${showShards ? 'show' : 'hide'} Shards Field`, () => {
        expect(findGeoSiteFormShardsField().exists()).toBe(showShards);
      });

      it(`${showOrganizations ? 'show' : 'hide'} Organizations Field`, () => {
        expect(findGeoSiteFormOrganizationsField().exists()).toBe(showOrganizations);
      });
    });
  });

  describe('events', () => {
    describe('update-sync-options', () => {
      beforeEach(() => {
        createComponent({
          siteData: {
            ...defaultProps.siteData,
            selectiveSyncType: MOCK_SELECTIVE_SYNC_TYPES.NAMESPACES.value,
          },
        });
      });

      describe('when form fields emits `update-sync-options` event', () => {
        it('emits `update-sync-options`', () => {
          findGeoSiteFormNamespacesField().vm.$emit('update-sync-options', MOCK_SYNC_NAMESPACE_IDS);

          expect(wrapper.emitted('update-sync-options')).toStrictEqual([[MOCK_SYNC_NAMESPACE_IDS]]);
        });
      });

      describe('when selectiveSyncType field emits `input` event', () => {
        it('emits `update-sync-options`', () => {
          findGeoSiteFormSyncTypeField().vm.$emit('input', MOCK_SELECTIVE_SYNC_TYPES.NAMESPACES);

          expect(wrapper.emitted('update-sync-options')).toStrictEqual([
            [{ key: 'selectiveSyncType', value: MOCK_SELECTIVE_SYNC_TYPES.NAMESPACES }],
          ]);
        });
      });
    });
  });

  describe('computed', () => {
    const factory = (
      selectiveSyncType = MOCK_SELECTIVE_SYNC_TYPES.ALL.value,
      selectiveSyncTypes = MOCK_SELECTIVE_SYNC_TYPES,
    ) => {
      createComponent({
        siteData: { ...defaultProps.siteData, selectiveSyncType },
        selectiveSyncTypes,
      });
    };

    describe('selectiveSyncOrganizationsAvailable', () => {
      it('returns true when ORGANIZATIONS is defined in selectiveSyncTypes', () => {
        factory();

        expect(wrapper.vm.selectiveSyncOrganizationsAvailable).toBe(true);
      });
    });

    describe('selectiveSyncFieldDescription', () => {
      it('returns description with organizations when organizations are available', () => {
        factory();

        expect(wrapper.vm.selectiveSyncFieldDescription).toBe(
          'Choose specific groups, storage shards, or organizations.',
        );
      });
    });

    describe('selectiveSyncPopoverText', () => {
      it('returns popover text with organizations when organizations are available', () => {
        factory();

        expect(wrapper.vm.selectiveSyncPopoverText).toBe(
          'Geo allows you to choose specific groups, storage shards, or organizations to replicate.',
        );
      });
    });

    describe('selectiveSyncNamespaces', () => {
      describe('when selectiveSyncType is not `NAMESPACES`', () => {
        beforeEach(() => {
          factory();
        });

        it('returns `false`', () => {
          expect(wrapper.vm.selectiveSyncNamespaces).toBe(false);
        });
      });

      describe('when selectiveSyncType is `NAMESPACES`', () => {
        beforeEach(() => {
          factory(MOCK_SELECTIVE_SYNC_TYPES.NAMESPACES.value);
        });

        it('returns `true`', () => {
          expect(wrapper.vm.selectiveSyncNamespaces).toBe(true);
        });
      });
    });

    describe('selectiveSyncShards', () => {
      describe('when selectiveSyncType is not `SHARDS`', () => {
        beforeEach(() => {
          factory(MOCK_SELECTIVE_SYNC_TYPES.ALL.value);
        });

        it('returns `false`', () => {
          expect(wrapper.vm.selectiveSyncShards).toBe(false);
        });
      });

      describe('when selectiveSyncType is `SHARDS`', () => {
        beforeEach(() => {
          factory(MOCK_SELECTIVE_SYNC_TYPES.SHARDS.value);
        });

        it('returns `true`', () => {
          expect(wrapper.vm.selectiveSyncShards).toBe(true);
        });
      });
    });
  });

  describe('when sync by organization is unavailable', () => {
    const { ORGANIZATIONS, ...selectiveSyncTypesNoOrganization } = MOCK_SELECTIVE_SYNC_TYPES;
    it('renders with correct text', () => {
      createComponent({ selectiveSyncTypes: selectiveSyncTypesNoOrganization });

      expect(findGeoSiteFormSyncTypeFormGroup().attributes('description')).toBe(
        'Choose specific groups or storage shards.',
      );
    });

    it('renders the GlPopover with correct text', () => {
      createComponent({ selectiveSyncTypes: selectiveSyncTypesNoOrganization });

      expect(findGeoSiteFormSyncTypePopover().text()).toContain(
        'Geo allows you to choose specific groups or storage shards to replicate.',
      );
    });

    describe('when current sync type is organizations', () => {
      it('does not render Organizations Field', () => {
        createComponent({
          selectiveSyncTypes: selectiveSyncTypesNoOrganization,
          siteData: { ...MOCK_SITE, selectiveSyncType: MOCK_SELECTIVE_SYNC_TYPES.ORGANIZATIONS },
        });

        expect(findGeoSiteFormOrganizationsField().exists()).toBe(false);
      });
    });
  });
});
