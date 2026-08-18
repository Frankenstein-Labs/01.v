import Vue, { nextTick } from 'vue';
import { GlBadge } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemVulnerabilities from 'ee/work_items/components/work_item_vulnerabilities.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { config } from '~/graphql_shared/issuable_client';
import workItemVulnerabilitiesQuery from 'ee/work_items/graphql/work_item_vulnerabilities.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemVulnerabilityItem from 'ee/work_items/components/work_item_vulnerability_item.vue';
import {
  vulnerabilitiesWidgetResponse,
  emptyVulnerabilitiesWidgetResponse,
  paginatedVulnerabilitiesWidgetResponse,
  getVulnerabilitiesWidgetResponse,
} from '../mock_data';

jest.mock('~/alert');

const items =
  vulnerabilitiesWidgetResponse.data.namespace.workItem.widgets[0].relatedVulnerabilities.nodes;

describe('WorkItemVulnerabilities component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemIid = '1';
  const fullPath = 'gitlab-org/security-reports';
  const successHandler = jest.fn().mockResolvedValue(vulnerabilitiesWidgetResponse);

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findAllVulnerabilityItems = () => wrapper.findAllComponents(WorkItemVulnerabilityItem);

  const createComponent = ({
    handler = successHandler,
    workItemFeaturesField = false,
    cacheConfig,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemVulnerabilities, {
      apolloProvider: createMockApollo([[workItemVulnerabilitiesQuery, handler]], {}, cacheConfig),
      propsData: {
        workItemIid,
        workItemFullPath: fullPath,
      },
      provide: {
        glFeatures: { workItemFeaturesField },
      },
      stubs: {
        CrudComponent,
      },
    });
  };

  beforeEach(async () => {
    createComponent();

    await waitForPromises();
  });

  describe('Default', () => {
    it('fetches vulnerabilities widget', () => {
      expect(successHandler).toHaveBeenCalledWith({
        iid: workItemIid,
        fullPath,
        first: 25,
        after: '',
        useWorkItemFeatures: false,
      });
    });

    it('shows CRUD Component', () => {
      const crudComponent = findCrudComponent();
      expect(crudComponent.props()).toMatchObject({
        title: 'Related vulnerabilities',
        anchorId: 'vulnerabilitiesitems',
      });
    });

    it('shows WorkItemVulnerabilityItem components', () => {
      expect(findAllVulnerabilityItems()).toHaveLength(2);
    });

    it('passes vulnerability to WorkItemVulnerabilityItem', () => {
      const firstItem = items[0];
      expect(findAllVulnerabilityItems().at(0).props('item')).toEqual(firstItem);
    });
  });

  describe('when workItemFeaturesField feature flag is enabled', () => {
    const featuresHandler = jest
      .fn()
      .mockResolvedValue(getVulnerabilitiesWidgetResponse(items, false, true));

    beforeEach(async () => {
      createComponent({ handler: featuresHandler, workItemFeaturesField: true });
      await waitForPromises();
    });

    it('fetches vulnerabilities with useWorkItemFeatures variable set to true', () => {
      expect(featuresHandler).toHaveBeenCalledWith({
        iid: workItemIid,
        fullPath,
        first: 25,
        after: '',
        useWorkItemFeatures: true,
      });
    });

    it('reads related vulnerabilities from the features field', () => {
      expect(findAllVulnerabilityItems()).toHaveLength(2);
      expect(findAllVulnerabilityItems().at(0).props('item')).toEqual(items[0]);
    });

    describe('load more', () => {
      const findWorkItemChildrenLoadMore = () =>
        wrapper.findComponentByTestId('work-item-vulnerabilities-load-more');
      const nextPageNodes = [
        {
          id: 'gid://gitlab/Vulnerability/999',
          state: 'DETECTED',
          severity: 'HIGH',
          name: 'SQL Injection',
          webUrl: '/vulnerabilities/999',
          __typename: 'Vulnerability',
        },
      ];

      let paginatedFeaturesHandler;

      beforeEach(async () => {
        paginatedFeaturesHandler = jest
          .fn()
          .mockResolvedValueOnce(getVulnerabilitiesWidgetResponse(items, true, true))
          .mockResolvedValueOnce(getVulnerabilitiesWidgetResponse(nextPageNodes, false, true));

        createComponent({
          handler: paginatedFeaturesHandler,
          workItemFeaturesField: true,
          cacheConfig: config.cacheConfig,
        });

        await waitForPromises();
      });

      it('fetches next page with useWorkItemFeatures set to true and appends nodes', async () => {
        expect(findAllVulnerabilityItems()).toHaveLength(items.length);

        findWorkItemChildrenLoadMore().vm.$emit('fetch-next-page');
        await waitForPromises();

        expect(paginatedFeaturesHandler).toHaveBeenNthCalledWith(2, {
          iid: workItemIid,
          fullPath,
          after: 'XYZ',
          first: 50,
          useWorkItemFeatures: true,
        });
        expect(findAllVulnerabilityItems()).toHaveLength(items.length + nextPageNodes.length);
      });
    });
  });

  describe('count badge', () => {
    it('shows correct aria-label and count with multiple related vulnerabilities', () => {
      const badge = findBadge();
      expect(badge.attributes('aria-label')).toBe('Issue has 2 related vulnerabilities');
      expect(badge.text()).toBe('2');
    });
  });

  describe('no related vulnerabilities', () => {
    beforeEach(async () => {
      createComponent({ handler: jest.fn().mockResolvedValue(emptyVulnerabilitiesWidgetResponse) });
      await waitForPromises;
    });

    it('does not show CrudComponent', () => {
      expect(findCrudComponent().exists()).toBe(false);
    });
  });

  describe('load more', () => {
    const findWorkItemChildrenLoadMore = () =>
      wrapper.findComponentByTestId('work-item-vulnerabilities-load-more');

    let paginatedHandler;

    beforeEach(async () => {
      paginatedHandler = jest.fn().mockResolvedValue(paginatedVulnerabilitiesWidgetResponse);

      createComponent({
        handler: paginatedHandler,
      });

      await waitForPromises();
    });

    it('shows `Load more` button when hasNextPage is true and node is expanded', () => {
      const loadMore = findWorkItemChildrenLoadMore();
      expect(loadMore.exists()).toBe(true);
      expect(loadMore.props('fetchNextPageInProgress')).toBe(false);
    });

    it('fetches next page when clicking on `Load more`', async () => {
      const loadMore = findWorkItemChildrenLoadMore();
      loadMore.vm.$emit('fetch-next-page');
      await nextTick();

      expect(loadMore.props('fetchNextPageInProgress')).toBe(true);
      await waitForPromises();

      expect(loadMore.props('fetchNextPageInProgress')).toBe(false);
      expect(paginatedHandler).toHaveBeenNthCalledWith(2, {
        iid: workItemIid,
        fullPath,
        after: 'XYZ',
        first: 50,
        useWorkItemFeatures: false,
      });
    });

    it('shows alert message when fetching next page fails', async () => {
      const rejectPaginationHandler = jest
        .fn()
        .mockResolvedValueOnce(paginatedVulnerabilitiesWidgetResponse)
        .mockRejectedValue('Error');
      createComponent({
        handler: rejectPaginationHandler,
      });

      await waitForPromises();
      findWorkItemChildrenLoadMore().vm.$emit('fetch-next-page');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        error: expect.any(Object),
        message: 'Something went wrong while fetching more related vulnerabilities.',
      });
    });
  });
});
