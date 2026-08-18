import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { workItemsRestResolver } from 'ee/work_items/list/graphql/rest/work_items_rest_resolver';

const FULL_PATH = 'gitlab-org/gitlab-shell';
const ENCODED_PATH = encodeURIComponent(FULL_PATH);
const ENDPOINT = `/api/v4/namespaces/${ENCODED_PATH}/-/work_items`;

const makeNamespace = (
  fullPath = FULL_PATH,
  id = 'gid://gitlab/Namespaces::ProjectNamespace/26',
) => ({
  id,
  fullPath,
  name: 'Gitlab Shell',
  __typename: 'Namespace',
});

const makeRestItem = (overrides = {}) => ({
  global_id: 'gid://gitlab/WorkItem/1',
  iid: 42,
  title: 'My work item',
  state: 'opened',
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-02T00:00:00Z',
  closed_at: null,
  reference: 'gitlab-org/gitlab-shell#42',
  web_path: '/gitlab-org/gitlab-shell/-/work_items/42',
  web_url: 'http://localhost/gitlab-org/gitlab-shell/-/work_items/42',
  user_discussions_count: 0,
  author: {
    id: 1,
    name: 'Administrator',
    username: 'root',
    avatar_url: 'http://localhost/avatar.png',
    web_path: '/root',
  },
  namespace: {
    id: 10,
    full_path: FULL_PATH,
  },
  work_item_type: {
    id: 5,
    name: 'Issue',
    icon_name: 'issue-type-issue',
  },
  features: null,
  ...overrides,
});

describe('EE workItemsRestResolver', () => {
  let mockAxios;

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
    window.gon = { api_version: 'v4' };
  });

  afterEach(() => {
    mockAxios.restore();
    delete window.gon;
  });

  describe.each([
    {
      type: 'HEALTH_STATUS',
      typename: 'WorkItemWidgetHealthStatus',
      propertyName: 'healthStatus',
      featureWithNull: { health_status: { health_status: null } },
    },
    {
      type: 'STATUS',
      typename: 'WorkItemWidgetStatus',
      propertyName: 'status',
      featureWithNull: { status: { status: null } },
    },
    {
      type: 'WEIGHT',
      typename: 'WorkItemWidgetWeight',
      propertyName: 'weight',
      featureWithNull: {
        weight: { weight: null, rolled_up_weight: null, rolled_up_completed_weight: null },
      },
    },
    {
      type: 'ITERATION',
      typename: 'WorkItemWidgetIteration',
      propertyName: 'iteration',
      featureWithNull: { iteration: { iteration: null } },
    },
  ])('$type widget mapping', ({ type, typename, propertyName, featureWithNull }) => {
    // An empty widget here leaks into the detail view, since the `widgets` policy unions.
    it.each([null, {}])(
      `omits the ${type} widget when the type does not support it (features is %p)`,
      async (featuresValue) => {
        const item = makeRestItem({ features: featuresValue });
        mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

        const { nodes } = await workItemsRestResolver(makeNamespace(), {});

        expect(nodes[0].widgets.find((w) => w.type === type)).toBeUndefined();
      },
    );

    it(`includes ${type} widget with null value from API`, async () => {
      const item = makeRestItem({ features: featureWithNull });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const widget = nodes[0].widgets.find((w) => w.type === type);

      expect(widget).toMatchObject({
        __typename: typename,
        type,
        [propertyName]: null,
      });
    });
  });

  describe('HEALTH_STATUS widget mapping', () => {
    it.each([
      ['on_track', 'onTrack'],
      ['needs_attention', 'needsAttention'],
      ['at_risk', 'atRisk'],
    ])('converts %s to %s in camelCase format', async (snakeCase, camelCase) => {
      const item = makeRestItem({
        features: {
          health_status: {
            health_status: snakeCase,
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const healthStatusWidget = nodes[0].widgets.find((w) => w.type === 'HEALTH_STATUS');

      expect(healthStatusWidget).toMatchObject({
        __typename: 'WorkItemWidgetHealthStatus',
        type: 'HEALTH_STATUS',
        healthStatus: camelCase,
      });
    });

    it('uses original value as fallback for unknown health status values', async () => {
      const item = makeRestItem({
        features: {
          health_status: {
            health_status: 'unknown_status',
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const healthStatusWidget = nodes[0].widgets.find((w) => w.type === 'HEALTH_STATUS');

      expect(healthStatusWidget).toMatchObject({
        __typename: 'WorkItemWidgetHealthStatus',
        type: 'HEALTH_STATUS',
        healthStatus: 'unknown_status',
      });
    });
  });

  describe('STATUS widget mapping', () => {
    it('maps status from features.status.status to STATUS widget', async () => {
      const item = makeRestItem({
        features: {
          status: {
            status: {
              id: 1,
              name: 'In Progress',
              category: 'started',
              color: '#428bca',
              description: 'Work is in progress',
              icon_name: 'status-running',
              position: 1,
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const statusWidget = nodes[0].widgets.find((w) => w.type === 'STATUS');

      expect(statusWidget).toMatchObject({
        __typename: 'WorkItemWidgetStatus',
        type: 'STATUS',
        status: {
          id: 1,
          name: 'In Progress',
          category: 'started',
          color: '#428bca',
          description: 'Work is in progress',
          iconName: 'status-running',
          position: 1,
          __typename: 'WorkItemStatus',
        },
      });
    });
  });

  describe('WEIGHT widget mapping', () => {
    it('maps weight from features.weight.weight to WEIGHT widget', async () => {
      const item = makeRestItem({
        features: {
          weight: {
            weight: 5,
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const weightWidget = nodes[0].widgets.find((w) => w.type === 'WEIGHT');

      expect(weightWidget).toMatchObject({
        __typename: 'WorkItemWidgetWeight',
        type: 'WEIGHT',
        weight: 5,
      });
    });

    it('handles weight value of 0', async () => {
      const item = makeRestItem({
        features: {
          weight: {
            weight: 0,
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const weightWidget = nodes[0].widgets.find((w) => w.type === 'WEIGHT');

      expect(weightWidget).toMatchObject({
        __typename: 'WorkItemWidgetWeight',
        type: 'WEIGHT',
        weight: 0,
      });
    });
  });

  describe('ITERATION widget mapping', () => {
    it('maps iteration from features.iteration.iteration to ITERATION widget', async () => {
      const item = makeRestItem({
        features: {
          iteration: {
            iteration: {
              id: 100,
              title: 'Sprint 1',
              start_date: '2024-01-01',
              due_date: '2024-01-14',
              web_url: 'https://gitlab.example.com/groups/my-group/-/iterations/1',
              iteration_cadence: {
                id: 10,
                title: 'Weekly Sprints',
              },
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const iterationWidget = nodes[0].widgets.find((w) => w.type === 'ITERATION');

      expect(iterationWidget).toMatchObject({
        __typename: 'WorkItemWidgetIteration',
        type: 'ITERATION',
        iteration: {
          id: 'gid://gitlab/Iteration/100',
          title: 'Sprint 1',
          startDate: '2024-01-01',
          dueDate: '2024-01-14',
          webUrl: 'https://gitlab.example.com/groups/my-group/-/iterations/1',
          iterationCadence: {
            id: 'gid://gitlab/Iterations::Cadence/10',
            title: 'Weekly Sprints',
            __typename: 'IterationCadence',
          },
          __typename: 'Iteration',
        },
      });
    });

    it('handles missing optional iteration fields', async () => {
      const item = makeRestItem({
        features: {
          iteration: {
            iteration: {
              id: 100,
              title: 'Sprint 1',
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const iterationWidget = nodes[0].widgets.find((w) => w.type === 'ITERATION');

      expect(iterationWidget.iteration).toMatchObject({
        __typename: 'Iteration',
        id: 'gid://gitlab/Iteration/100',
        title: 'Sprint 1',
        startDate: null,
        dueDate: null,
        webUrl: null,
        iterationCadence: null,
      });
    });
  });

  describe('HIERARCHY widget mapping', () => {
    // CE maps HIERARCHY unconditionally, so it stays present with no `hierarchy` key.
    it.each([null, {}, { hierarchy: { parent: null, has_parent: false } }])(
      'includes the HIERARCHY widget with a null parent when features is %p',
      async (featuresValue) => {
        const item = makeRestItem({ features: featuresValue });
        mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

        const { nodes } = await workItemsRestResolver(makeNamespace(), {});

        expect(nodes[0].widgets.find((w) => w.type === 'HIERARCHY')).toMatchObject({
          __typename: 'WorkItemWidgetHierarchy',
          type: 'HIERARCHY',
          parent: null,
        });
      },
    );

    it('maps parent from features.hierarchy.parent to HIERARCHY widget', async () => {
      const item = makeRestItem({
        features: {
          hierarchy: {
            parent: {
              global_id: 'gid://gitlab/WorkItem/10',
              iid: 5,
              title: 'Parent work item',
              title_html: '<p>Parent work item</p>',
              confidential: true,
              web_url: 'https://gitlab.example.com/work_items/10',
              work_item_type: {
                id: 1,
                name: 'Epic',
                icon_name: 'issue-type-epic',
              },
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const hierarchyWidget = nodes[0].widgets.find((w) => w.type === 'HIERARCHY');

      expect(hierarchyWidget).toMatchObject({
        __typename: 'WorkItemWidgetHierarchy',
        type: 'HIERARCHY',
        parent: {
          __typename: 'WorkItem',
          id: 'gid://gitlab/WorkItem/10',
          iid: '5',
          title: 'Parent work item',
          titleHtml: '<p>Parent work item</p>',
          confidential: true,
          webUrl: 'https://gitlab.example.com/work_items/10',
          namespace: makeNamespace(),
          workItemType: {
            __typename: 'WorkItemType',
            id: 'gid://gitlab/WorkItems::Type/1',
            name: 'Epic',
            iconName: 'issue-type-epic',
          },
        },
      });
    });

    it('maps a parent to its own namespace when it differs from the list namespace', async () => {
      const item = makeRestItem({
        features: {
          hierarchy: {
            parent: {
              global_id: 'gid://gitlab/WorkItem/10',
              iid: 5,
              title: 'Parent work item',
              namespace: {
                id: 77,
                kind: 'group',
                full_path: 'other-group',
              },
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const hierarchyWidget = nodes[0].widgets.find((w) => w.type === 'HIERARCHY');

      expect(hierarchyWidget.parent.namespace).toEqual({
        __typename: 'Namespace',
        id: 'gid://gitlab/Namespaces::GroupNamespace/77',
        fullPath: 'other-group',
      });
    });

    it('handles missing optional parent fields', async () => {
      const item = makeRestItem({
        features: {
          hierarchy: {
            parent: {
              global_id: 'gid://gitlab/WorkItem/10',
              iid: 5,
              title: 'Parent work item',
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const hierarchyWidget = nodes[0].widgets.find((w) => w.type === 'HIERARCHY');

      expect(hierarchyWidget.parent).toMatchObject({
        __typename: 'WorkItem',
        id: 'gid://gitlab/WorkItem/10',
        iid: '5',
        title: 'Parent work item',
        confidential: false,
        webUrl: null,
        workItemType: null,
      });
    });
  });

  describe('LINKED_ITEMS widget mapping', () => {
    it('maps linked_items from features.linked_items to LINKED_ITEMS widget with default counts', async () => {
      const item = makeRestItem({
        features: {
          linked_items: {
            blocking_count: 0,
            blocked_by_count: 0,
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const linkedItemsWidget = nodes[0].widgets.find((w) => w.type === 'LINKED_ITEMS');

      expect(linkedItemsWidget).toMatchObject({
        __typename: 'WorkItemWidgetLinkedItems',
        type: 'LINKED_ITEMS',
        blockingCount: 0,
        blockedByCount: 0,
      });
    });

    it('maps linked_items with custom counts', async () => {
      const item = makeRestItem({
        features: {
          linked_items: {
            blocking_count: 3,
            blocked_by_count: 5,
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const linkedItemsWidget = nodes[0].widgets.find((w) => w.type === 'LINKED_ITEMS');

      expect(linkedItemsWidget).toMatchObject({
        __typename: 'WorkItemWidgetLinkedItems',
        type: 'LINKED_ITEMS',
        blockingCount: 3,
        blockedByCount: 5,
      });
    });

    it('handles zero blocking_count and non-zero blocked_by_count', async () => {
      const item = makeRestItem({
        features: {
          linked_items: {
            blocking_count: 0,
            blocked_by_count: 2,
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});
      const linkedItemsWidget = nodes[0].widgets.find((w) => w.type === 'LINKED_ITEMS');

      expect(linkedItemsWidget).toMatchObject({
        __typename: 'WorkItemWidgetLinkedItems',
        type: 'LINKED_ITEMS',
        blockingCount: 0,
        blockedByCount: 2,
      });
    });
  });

  describe('EE features mapping', () => {
    beforeEach(() => {
      window.gon = { api_version: 'v4', features: { workItemFeaturesField: true } };
    });

    it('returns populated features (alongside widgets) on each work item when the flag is enabled', async () => {
      const item = makeRestItem();
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features).toMatchObject({ __typename: 'WorkItemFeatures' });
      expect(nodes[0].features.labels).not.toBeNull();
      expect(nodes[0].widgets.length).toBeGreaterThan(0);
    });

    it('returns widgets (and a null-valued features placeholder) when the flag is disabled', async () => {
      window.gon = { api_version: 'v4', features: { workItemFeaturesField: false } };
      const item = makeRestItem();
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].widgets.length).toBeGreaterThan(0);
      expect(nodes[0].features).toMatchObject({
        __typename: 'WorkItemFeatures',
        labels: null,
        assignees: null,
        milestone: null,
        startAndDueDate: null,
        hierarchy: null,
        status: null,
        healthStatus: null,
        weight: null,
        iteration: null,
        linkedItems: null,
      });
    });

    it('maps status to features.status', async () => {
      const item = makeRestItem({
        features: {
          status: {
            status: {
              id: 1,
              name: 'In Progress',
              category: 'started',
              color: '#428bca',
              description: 'Work is in progress',
              icon_name: 'status-running',
              position: 1,
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features.status).toMatchObject({
        __typename: 'WorkItemWidgetStatus',
        status: {
          __typename: 'WorkItemStatus',
          id: 1,
          name: 'In Progress',
          category: 'started',
          color: '#428bca',
          description: 'Work is in progress',
          iconName: 'status-running',
          position: 1,
        },
      });
    });

    it.each([
      ['on_track', 'onTrack'],
      ['needs_attention', 'needsAttention'],
      ['at_risk', 'atRisk'],
    ])('maps health_status %s to features.healthStatus as %s', async (snakeCase, camelCase) => {
      const item = makeRestItem({
        features: {
          health_status: { health_status: snakeCase },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features.healthStatus).toMatchObject({
        __typename: 'WorkItemWidgetHealthStatus',
        healthStatus: camelCase,
      });
    });

    it('maps weight to features.weight', async () => {
      const item = makeRestItem({
        features: {
          weight: { weight: 5 },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features.weight).toMatchObject({
        __typename: 'WorkItemWidgetWeight',
        weight: 5,
      });
    });

    it('maps iteration to features.iteration', async () => {
      const item = makeRestItem({
        features: {
          iteration: {
            iteration: {
              id: 100,
              title: 'Sprint 1',
              start_date: '2024-01-01',
              due_date: '2024-01-14',
              web_url: 'https://gitlab.example.com/groups/my-group/-/iterations/1',
              iteration_cadence: {
                id: 10,
                title: 'Weekly Sprints',
              },
            },
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features.iteration).toMatchObject({
        __typename: 'WorkItemWidgetIteration',
        iteration: {
          __typename: 'Iteration',
          id: 'gid://gitlab/Iteration/100',
          title: 'Sprint 1',
          startDate: '2024-01-01',
          dueDate: '2024-01-14',
          webUrl: 'https://gitlab.example.com/groups/my-group/-/iterations/1',
          iterationCadence: {
            __typename: 'IterationCadence',
            id: 'gid://gitlab/Iterations::Cadence/10',
            title: 'Weekly Sprints',
          },
        },
      });
    });

    it('maps linked_items to features.linkedItems', async () => {
      const item = makeRestItem({
        features: {
          linked_items: {
            blocking_count: 3,
            blocked_by_count: 5,
          },
        },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features.linkedItems).toMatchObject({
        __typename: 'WorkItemWidgetLinkedItems',
        blockingCount: 3,
        blockedByCount: 5,
      });
    });

    it('includes CE features (labels, assignees, milestone, startAndDueDate, hierarchy)', async () => {
      const item = makeRestItem();
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features.labels).toBeDefined();
      expect(nodes[0].features.assignees).toBeDefined();
      expect(nodes[0].features.milestone).toBeDefined();
      expect(nodes[0].features.startAndDueDate).toBeDefined();
      expect(nodes[0].features.hierarchy).toBeDefined();
    });

    // An empty feature here survives the detail query, since the `features` policy merges.
    it.each([null, {}])(
      'returns null EE features when the type does not support them (features is %p)',
      async (featuresValue) => {
        const item = makeRestItem({ features: featuresValue });
        mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

        const { nodes } = await workItemsRestResolver(makeNamespace(), {});

        expect(nodes[0].features).toMatchObject({
          status: null,
          healthStatus: null,
          weight: null,
          iteration: null,
          linkedItems: null,
        });
      },
    );

    it('maps only the EE features the REST response includes', async () => {
      const item = makeRestItem({
        features: { health_status: { health_status: null }, weight: { weight: null } },
      });
      mockAxios.onGet(ENDPOINT).reply(HTTP_STATUS_OK, [item], {});

      const { nodes } = await workItemsRestResolver(makeNamespace(), {});

      expect(nodes[0].features).toMatchObject({
        healthStatus: { __typename: 'WorkItemWidgetHealthStatus', healthStatus: null },
        weight: { __typename: 'WorkItemWidgetWeight', weight: null },
        status: null,
        iteration: null,
        linkedItems: null,
      });
    });
  });
});
