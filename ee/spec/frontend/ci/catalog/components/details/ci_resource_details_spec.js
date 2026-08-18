import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTab, GlAlert, GlLoadingIcon, GlEmptyState } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CiResourceDetails from 'ee/ci/catalog/components/details/ci_resource_details.vue';
import CeCiResourceDetails from '~/ci/catalog/components/details/ci_resource_details.vue';
import UsageDetails from 'ee/ci/catalog/components/details/usage_details.vue';
import getCatalogResourceUsage from 'ee/ci/catalog/graphql/queries/get_resource_usage.query.graphql';
import getCatalogResourceUsagePermissions from 'ee/ci/catalog/graphql/queries/get_resource_usage_permissions.query.graphql';
import {
  mockUsageData,
  mockUsageDataPage2,
  mockEmptyUsageData,
  mockPageInfo,
  mockPermissionsData,
} from './mock_data';

Vue.use(VueApollo);

const resourcePath = 'root/my-component';
const version = '1.0.1';

describe('CiResourceDetails', () => {
  let wrapper;

  const createComponent = ({
    permissionsHandler = jest.fn().mockResolvedValue(mockPermissionsData),
    usageHandler = jest.fn().mockResolvedValue(mockUsageData),
  } = {}) => {
    const handlers = [
      [getCatalogResourceUsagePermissions, permissionsHandler],
      [getCatalogResourceUsage, usageHandler],
    ];
    const mockApollo = createMockApollo(handlers);

    wrapper = shallowMount(CiResourceDetails, {
      apolloProvider: mockApollo,
      propsData: {
        resourcePath,
        version,
      },
    });
  };

  const findCeDetails = () => wrapper.findComponent(CeCiResourceDetails);
  const findTab = () => wrapper.findComponent(GlTab);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findUsageDetails = () => wrapper.findComponent(UsageDetails);

  describe('rendering the CE component', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the CE details component with the resource path and version', () => {
      expect(findCeDetails().exists()).toBe(true);
      expect(findCeDetails().props('resourcePath')).toBe(resourcePath);
      expect(findCeDetails().props('version')).toBe(version);
    });
  });

  describe('usage tab visibility', () => {
    it.each`
      scenario                                                       | licensedFeature | hasPermissions | shouldRender
      ${'does not render when licensed feature is not available'}    | ${false}        | ${true}        | ${false}
      ${'does not render when user does not have permission'}        | ${true}         | ${false}       | ${false}
      ${'renders when feature is available and user has permission'} | ${true}         | ${true}        | ${true}
    `('$scenario', async ({ licensedFeature, hasPermissions, shouldRender }) => {
      const permissionsData = {
        data: {
          project: {
            id: 'gid://gitlab/Project/1',
            userPermissions: {
              readProject: true,
              readProjectComponentUsages: hasPermissions,
            },
            licensedFeatureAvailability: {
              available: licensedFeature,
            },
          },
        },
      };

      createComponent({
        permissionsHandler: jest.fn().mockResolvedValue(permissionsData),
      });
      await waitForPromises();

      expect(findTab().exists()).toBe(shouldRender);
    });

    it('assigns the usage query param value to the tab', async () => {
      createComponent();
      await waitForPromises();

      expect(findTab().props('queryParamValue')).toBe('usage');
    });
  });

  describe('when deep-linked to the usage tab', () => {
    beforeEach(() => {
      setWindowLocation('?tab=usage');
    });

    it('shows a loading icon and does not render the CE component while permissions resolve', () => {
      createComponent({
        permissionsHandler: jest.fn().mockReturnValue(new Promise(() => {})),
      });

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findCeDetails().exists()).toBe(false);
    });

    it('renders the CE component with the usage tab once permissions resolve', async () => {
      createComponent();
      await waitForPromises();

      expect(findCeDetails().exists()).toBe(true);
      expect(findTab().exists()).toBe(true);
    });

    it('renders the CE component without the usage tab once permissions resolve', async () => {
      createComponent({
        permissionsHandler: jest.fn().mockResolvedValue({
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              userPermissions: { readProject: true, readProjectComponentUsages: false },
              licensedFeatureAvailability: { available: false },
            },
          },
        }),
      });
      await waitForPromises();

      expect(findCeDetails().exists()).toBe(true);
      expect(findTab().exists()).toBe(false);
    });
  });

  describe('when not on the usage tab', () => {
    beforeEach(() => {
      setWindowLocation('?tab=components');
    });

    it('renders the CE component immediately without waiting for the permissions check', () => {
      createComponent({
        permissionsHandler: jest.fn().mockReturnValue(new Promise(() => {})),
      });

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findCeDetails().exists()).toBe(true);
    });
  });

  describe('loading state', () => {
    it('shows loading icon while fetching usage data', async () => {
      createComponent({
        usageHandler: jest.fn().mockReturnValue(new Promise(() => {})),
      });
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findUsageDetails().exists()).toBe(false);
    });
  });

  describe('error state', () => {
    beforeEach(async () => {
      createComponent({
        usageHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      await waitForPromises();
    });

    it('shows error alert', () => {
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().text()).toBe(
        'An error occurred while fetching usage statistics. Refresh the page or try again later.',
      );
    });

    it('does not show loading icon or usage details', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findUsageDetails().exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      createComponent({
        usageHandler: jest.fn().mockResolvedValue(mockEmptyUsageData),
      });
      await waitForPromises();
    });

    it('shows empty state when no usage data', () => {
      expect(findEmptyState().props('title')).toBe('No usage data available');
      expect(findEmptyState().props('description')).toBe(
        "There are no projects using this resource in the last 30 days, or you don't have permission to view them.",
      );
    });

    it('does not show loading icon or usage details', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findUsageDetails().exists()).toBe(false);
    });
  });

  describe('with usage data', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders usage details component with correct props', () => {
      expect(findUsageDetails().props('componentUsages')).toEqual(
        mockUsageData.data.ciCatalogResource.projectComponentUsages.nodes,
      );
      expect(findUsageDetails().props('pageInfo')).toEqual(mockPageInfo);
      expect(findUsageDetails().props('resourcePath')).toBe(resourcePath);
      expect(findUsageDetails().props('isLoading')).toBe(false);
    });

    it('does not show loading icon, error, or empty state', () => {
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('filtering', () => {
    const queryHandler = jest.fn();

    beforeEach(async () => {
      queryHandler.mockResolvedValue(mockUsageData);
      createComponent({ usageHandler: queryHandler });
      await waitForPromises();
    });

    it('sends null for versionIds and componentName on initial load', () => {
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          fullPath: resourcePath,
          versionIds: null,
          componentName: null,
          first: 20,
        }),
      );
    });

    it('refetches with filters when usage details emits filters-changed', async () => {
      const versionIds = [
        'gid://gitlab/Ci::Catalog::Resources::Version/1',
        'gid://gitlab/Ci::Catalog::Resources::Version/2',
      ];

      findUsageDetails().vm.$emit('filters-changed', {
        componentName: 'build',
        versionIds,
      });
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          fullPath: resourcePath,
          componentName: 'build',
          versionIds,
          first: 20,
        }),
      );
    });

    it('resets pagination when filters change', async () => {
      findUsageDetails().vm.$emit('next-page');
      await waitForPromises();
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ after: mockPageInfo.endCursor }),
      );

      findUsageDetails().vm.$emit('filters-changed', {
        componentName: 'build',
        versionIds: [],
      });
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.not.objectContaining({ after: mockPageInfo.endCursor }),
      );
      expect(queryHandler).toHaveBeenLastCalledWith(expect.objectContaining({ first: 20 }));
    });

    it('does not show the empty state when filters yield no results', async () => {
      queryHandler.mockResolvedValueOnce(mockEmptyUsageData);

      findUsageDetails().vm.$emit('filters-changed', {
        componentName: 'no-match',
        versionIds: [],
      });
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(false);
      expect(findUsageDetails().exists()).toBe(true);
    });
  });

  describe('sorting', () => {
    const queryHandler = jest.fn();

    beforeEach(async () => {
      queryHandler.mockResolvedValue(mockUsageData);
      createComponent({ usageHandler: queryHandler });
      await waitForPromises();
    });

    it('sends the default sort on initial load', () => {
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ sort: 'OLDEST_VERSION_ASC' }),
      );
    });

    it('refetches with the new sort when usage details emits sort', async () => {
      findUsageDetails().vm.$emit('sort', 'LAST_USED_DESC');
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ sort: 'LAST_USED_DESC', first: 20 }),
      );
    });

    it('resets pagination when sort changes', async () => {
      findUsageDetails().vm.$emit('next-page');
      await waitForPromises();
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ after: mockPageInfo.endCursor }),
      );

      findUsageDetails().vm.$emit('sort', 'PROJECT_NAME_ASC');
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.not.objectContaining({ after: mockPageInfo.endCursor }),
      );
      expect(queryHandler).toHaveBeenLastCalledWith(expect.objectContaining({ first: 20 }));
    });
  });

  describe('internal event tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('tracks click_component_usage_tab_on_ci_catalog when the tab is clicked', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      findTab().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_component_usage_tab_on_ci_catalog',
        {},
        undefined,
      );
    });
  });

  describe('pagination', () => {
    const queryHandler = jest.fn();

    beforeEach(async () => {
      queryHandler.mockResolvedValueOnce(mockUsageData);
      createComponent({ usageHandler: queryHandler });
      await waitForPromises();
    });

    it('fetches next page when usage details emits next-page', async () => {
      queryHandler.mockResolvedValueOnce(mockUsageDataPage2);

      findUsageDetails().vm.$emit('next-page');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(2);
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          first: 20,
          after: mockPageInfo.endCursor,
        }),
      );
    });

    it('fetches previous page when usage details emits prev-page', async () => {
      queryHandler.mockResolvedValueOnce(mockUsageDataPage2);
      findUsageDetails().vm.$emit('next-page');
      await waitForPromises();

      queryHandler.mockResolvedValueOnce(mockUsageData);
      findUsageDetails().vm.$emit('prev-page');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(3);
      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          last: 20,
          before:
            mockUsageDataPage2.data.ciCatalogResource.projectComponentUsages.pageInfo.startCursor,
        }),
      );
    });
  });
});
