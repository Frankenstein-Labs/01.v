import { GlButton } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import NamespaceStorageApp from '~/usage_quotas/storage/namespace/components/namespace_storage_app.vue';
import ProjectList from '~/usage_quotas/storage/namespace/components/project_list.vue';
import getNamespaceStorageQuery from 'ee/usage_quotas/storage/namespace/queries/namespace_storage.query.graphql';
import getProjectListStorageQuery from 'ee/usage_quotas/storage/namespace/queries/project_list_storage.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import StorageUsageStatistics from 'ee/usage_quotas/storage/namespace/components/storage_usage_statistics.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  mockGetNamespaceStorageGraphQLResponse,
  mockGetProjectListStorageGraphQLResponse,
} from 'jest/usage_quotas/storage/mock_data';
import { defaultNamespaceProvideValues } from '../../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('NamespaceStorageApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const getNamespaceStorageHandler = jest.fn();
  const getProjectListStorageHandler = jest.fn();

  const findStorageUsageStatistics = () => wrapper.findComponent(StorageUsageStatistics);
  const findProjectList = () => wrapper.findComponent(ProjectList);

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = mountExtended(NamespaceStorageApp, {
      apolloProvider: createMockApollo([
        [getNamespaceStorageQuery, getNamespaceStorageHandler],
        [getProjectListStorageQuery, getProjectListStorageHandler],
      ]),
      provide: {
        ...defaultNamespaceProvideValues,
        ...provide,
      },
      stubs: {
        StorageUsageStatistics: true,
      },
    });
  };

  beforeEach(() => {
    getNamespaceStorageHandler.mockResolvedValue(mockGetNamespaceStorageGraphQLResponse);
    getProjectListStorageHandler.mockResolvedValue(mockGetProjectListStorageGraphQLResponse);
  });

  describe('Namespace usage overview', () => {
    beforeEach(async () => {
      createComponent({
        provide: {
          purchaseStorageUrl: 'some-fancy-url',
        },
      });
      await waitForPromises();
    });

    it('renders purchase more storage button', () => {
      const purchaseButton = wrapper.findComponent(GlButton);

      expect(purchaseButton.exists()).toBe(true);
    });
  });

  describe('sorting projects', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets default sorting', () => {
      expect(getProjectListStorageHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          sortKey: 'STORAGE_SIZE_DESC',
        }),
      );
      const projectList = findProjectList();
      expect(projectList.props('sortBy')).toBe('storage');
    });

    it('forms a sorting order string for STORAGE sorting', async () => {
      findProjectList().vm.$emit('sort-changed', { sortBy: 'storage', sortDesc: false });
      await waitForPromises();
      expect(getProjectListStorageHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          sortKey: 'STORAGE_SIZE_ASC',
        }),
      );
    });
  });

  describe('storage-usage-statistics', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes costFactoredStorageSize as usedStorage', () => {
      expect(findStorageUsageStatistics().props('usedStorage')).toBe(
        mockGetNamespaceStorageGraphQLResponse.data.namespace.rootStorageStatistics
          .costFactoredStorageSize,
      );
    });
  });

  // https://docs.gitlab.com/ee/user/storage_usage_quotas#project-storage-limit
  describe('Namespace under Project type storage enforcement', () => {
    it('sets default sorting to STORAGE_SIZE_DESC, when the limit is NOT set', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithNoLimits: true,
        },
      });

      expect(getProjectListStorageHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          sortKey: 'STORAGE_SIZE_DESC',
        }),
      );

      const projectList = findProjectList();
      expect(projectList.props('sortBy')).toBe('storage');
    });

    it('sets default sorting to STORAGE, when the limit is set', () => {
      createComponent({
        provide: {
          isUsingNamespaceEnforcement: false,
          isUsingProjectEnforcementWithLimits: true,
          customSortKey: 'EXCESS_REPO_STORAGE_SIZE_DESC',
        },
      });

      expect(getProjectListStorageHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          sortKey: 'EXCESS_REPO_STORAGE_SIZE_DESC',
        }),
      );

      const projectList = findProjectList();
      expect(projectList.props('sortBy')).toBe(null);
    });
  });
});
