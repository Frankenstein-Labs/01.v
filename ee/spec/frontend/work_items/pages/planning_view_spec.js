import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';

import PlanningView from '~/work_items/pages/planning_view.vue';
import PlanningViewEE from 'ee/work_items/pages/planning_view.vue';

import {
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_ISSUE,
  WORK_ITEM_TYPE_NAME_TASK,
  WORK_ITEM_TYPE_NAME_TICKET,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import {
  TOKEN_TITLE_WEIGHT,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_HEALTH,
  TOKEN_TITLE_HEALTH,
  TOKEN_TYPE_STATUS,
  TOKEN_TITLE_STATUS,
  TOKEN_TYPE_ITERATION,
  TOKEN_TITLE_ITERATION,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import searchIterationsQuery from 'ee/work_items/list/graphql/search_iterations.query.graphql';
import { mockNamespaceCustomFieldsResponse } from 'ee_jest/vue_shared/components/filtered_search_bar/mock_data';

Vue.use(VueApollo);

const mockIterationsResponse = {
  data: {
    project: {
      iterations: {
        nodes: [
          { id: 'gid://gitlab/Iteration/1', title: 'Iteration 1' },
          { id: 'gid://gitlab/Iteration/2', title: 'Iteration 2' },
        ],
      },
    },
  },
};

const baseCustomFieldsQueryHandler = jest.fn().mockResolvedValue(mockNamespaceCustomFieldsResponse);
const iterationsQueryHandler = jest.fn().mockResolvedValue(mockIterationsResponse);

let wrapper;

const mountComponent = (provide) => {
  wrapper = shallowMountExtended(PlanningViewEE, {
    apolloProvider: createMockApollo([
      [namespaceCustomFieldsQuery, baseCustomFieldsQueryHandler],
      [searchIterationsQuery, iterationsQueryHandler],
    ]),
    provide: {
      hasEpicsFeature: true,
      isGroup: true,
      showNewWorkItem: true,
      hasCustomFieldsFeature: true,
      hasIssueWeightsFeature: false,
      hasIssuableHealthStatusFeature: false,
      hasIterationsFeature: false,
      workItemType: WORK_ITEM_TYPE_NAME_EPIC,
      hasStatusFeature: true,
      workItemTypesConfiguration: [
        { id: 'gid://gitlab/WorkItems::Type/1', name: 'Issue', isFilterableListView: true },
        { id: 'gid://gitlab/WorkItems::Type/2', name: 'Incident', isFilterableListView: true },
        { id: 'gid://gitlab/WorkItems::Type/3', name: 'Test Case', isFilterableListView: false },
        { id: 'gid://gitlab/WorkItems::Type/4', name: 'Requirement', isFilterableListView: false },
        { id: 'gid://gitlab/WorkItems::Type/5', name: 'Task', isFilterableListView: true },
        { id: 'gid://gitlab/WorkItems::Type/6', name: 'Objective', isFilterableListView: false },
        { id: 'gid://gitlab/WorkItems::Type/7', name: 'Key Result', isFilterableListView: false },
        { id: 'gid://gitlab/WorkItems::Type/8', name: 'Epic', isFilterableListView: false },
        { id: 'gid://gitlab/WorkItems::Type/9', name: 'Ticket', isFilterableListView: true },
      ],
      ...provide,
    },
    propsData: {
      rootPageFullPath: 'gitlab-org',
    },
  });
};

const findPlanningViewCE = () => wrapper.findComponent(PlanningView);

describe('filter tokens', () => {
  const findToken = (type) => {
    const eeSearchTokens = findPlanningViewCE().props('eeSearchTokens');
    return eeSearchTokens.find((token) => token.type === type);
  };

  describe('custom fields', () => {
    const mockCustomFields = mockNamespaceCustomFieldsResponse.data.namespace.customFields.nodes;
    const epicListAllowedFields = mockCustomFields.filter(
      (field) =>
        [CUSTOM_FIELDS_TYPE_SINGLE_SELECT, CUSTOM_FIELDS_TYPE_MULTI_SELECT].includes(
          field.fieldType,
        ) && field.workItemTypes.some((type) => type.name === WORK_ITEM_TYPE_NAME_EPIC),
    );
    const issueListAllowedFields = mockCustomFields.filter(
      (field) =>
        [CUSTOM_FIELDS_TYPE_SINGLE_SELECT, CUSTOM_FIELDS_TYPE_MULTI_SELECT].includes(
          field.fieldType,
        ) &&
        field.workItemTypes.some(
          (type) =>
            type.name === WORK_ITEM_TYPE_NAME_ISSUE || type.name === WORK_ITEM_TYPE_NAME_TASK,
        ),
    );
    const findCustomFieldTokens = () =>
      findPlanningViewCE()
        .props('eeSearchTokens')
        .filter((token) => token.type.startsWith(TOKEN_TYPE_CUSTOM_FIELD));

    const getExpectedTokens = (fields) => {
      return fields.map((field) => ({
        type: `${TOKEN_TYPE_CUSTOM_FIELD}[${field.id.split('/').pop()}]`,
        title: field.name,
        icon: 'multiple-choice',
        field,
        fullPath: 'gitlab-org',
        token: expect.any(Function),
        operators: OPERATORS_IS,
        unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
      }));
    };

    it('excludes custom field tokens when feature is disabled', async () => {
      await mountComponent({ hasCustomFieldsFeature: false });
      await waitForPromises();

      const customFieldTokens = findCustomFieldTokens();

      expect(customFieldTokens).toHaveLength(0);
      expect(baseCustomFieldsQueryHandler).not.toHaveBeenCalled(); // Verify query was skipped
    });

    it('includes custom field tokens when feature is enabled', async () => {
      await mountComponent();
      await waitForPromises();

      const customFieldTokens = findCustomFieldTokens();

      expect(customFieldTokens).toHaveLength(3);
    });

    it('fetches custom fields when component is mounted', async () => {
      await mountComponent();
      await waitForPromises();

      expect(baseCustomFieldsQueryHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org',
        active: true,
      });
    });

    it('passes custom field tokens to ListView and unique field is based on field type', async () => {
      await mountComponent();
      await waitForPromises();

      expect(findPlanningViewCE().props('eeSearchTokens')).toHaveLength(3);
      expect(findPlanningViewCE().props('eeSearchTokens')[0]).toMatchObject(
        getExpectedTokens(epicListAllowedFields)[0],
      );
      expect(findPlanningViewCE().props('eeSearchTokens')[1]).toMatchObject(
        getExpectedTokens(epicListAllowedFields)[1],
      );
    });

    it('does not have epics custom fields token on issues list', async () => {
      await mountComponent({ workItemType: null, hasStatusFeature: false });
      await waitForPromises();

      expect(findPlanningViewCE().props('eeSearchTokens')).toHaveLength(3);

      expect(findPlanningViewCE().props('eeSearchTokens')[0]).toMatchObject(
        getExpectedTokens(issueListAllowedFields)[0],
      );
      expect(findPlanningViewCE().props('eeSearchTokens')[1]).toMatchObject(
        getExpectedTokens(issueListAllowedFields)[1],
      );
      expect(findPlanningViewCE().props('eeSearchTokens')[2]).toMatchObject(
        getExpectedTokens(issueListAllowedFields)[2],
      );
    });
  });

  describe('weight', () => {
    it('excludes weight token when feature is disabled', async () => {
      await mountComponent({
        hasIssueWeightsFeature: false,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const weightToken = findToken(TOKEN_TYPE_WEIGHT);

      expect(weightToken).toBeUndefined();
    });

    it('excludes weight token when feature is enabled but on epics list', async () => {
      await mountComponent({
        hasIssueWeightsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
      await waitForPromises();

      const weightToken = findToken(TOKEN_TYPE_WEIGHT);

      expect(weightToken).toBeUndefined();
    });

    it('includes weight token when feature is enabled and not on epics list', async () => {
      await mountComponent({
        hasIssueWeightsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const weightToken = findToken(TOKEN_TYPE_WEIGHT);

      expect(weightToken).toMatchObject({
        type: TOKEN_TYPE_WEIGHT,
        title: TOKEN_TITLE_WEIGHT,
        icon: 'weight',
        token: expect.any(Function),
        unique: true,
      });
    });
  });

  describe('health status', () => {
    it('excludes health token when feature is disabled', async () => {
      await mountComponent({
        hasIssuableHealthStatusFeature: false,
        workItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
      await waitForPromises();

      const healthToken = findToken(TOKEN_TYPE_HEALTH);

      expect(healthToken).toBeUndefined();
    });

    it('includes health token for issues when feature is enabled', async () => {
      await mountComponent({
        hasIssuableHealthStatusFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const healthToken = findToken(TOKEN_TYPE_HEALTH);

      expect(healthToken).toMatchObject({
        type: TOKEN_TYPE_HEALTH,
        title: TOKEN_TITLE_HEALTH,
        icon: 'status-health',
        token: expect.any(Function),
        unique: true,
      });
    });
  });

  describe('iteration', () => {
    it('excludes iteration token when feature is disabled', async () => {
      await mountComponent({
        hasIterationsFeature: false,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const iterationToken = findToken(TOKEN_TYPE_ITERATION);

      expect(iterationToken).toBeUndefined();
    });

    it('excludes iteration token when feature is enabled but on epics list', async () => {
      await mountComponent({
        hasIterationsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_EPIC,
      });
      await waitForPromises();

      const iterationToken = findToken(TOKEN_TYPE_ITERATION);

      expect(iterationToken).toBeUndefined();
    });

    it('includes iteration token when feature is enabled and not on epics list', async () => {
      await mountComponent({
        hasIterationsFeature: true,
        workItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      const iterationToken = findToken(TOKEN_TYPE_ITERATION);

      expect(iterationToken).toMatchObject({
        type: TOKEN_TYPE_ITERATION,
        title: TOKEN_TITLE_ITERATION,
        icon: 'iteration',
        token: expect.any(Function),
        fetchIterations: expect.any(Function),
        recentSuggestionsStorageKey: 'gitlab-org-work-items-recent-tokens-iteration',
        fullPath: 'gitlab-org',
        isProject: false,
      });
    });
  });

  describe('status token', () => {
    it('excludes status token when feature is disabled and group work items list', async () => {
      await mountComponent({
        hasStatusFeature: false,
        isGroup: true,
      });
      await waitForPromises();

      const statusToken = findToken(TOKEN_TYPE_STATUS);

      expect(statusToken).toBeUndefined();
    });

    it('includes status token when feature is enabled and group work item lists', async () => {
      await mountComponent({
        hasStatusFeature: true,
        isGroup: true,
        workItemType: null,
      });
      await waitForPromises();

      const statusToken = findToken(TOKEN_TYPE_STATUS);

      expect(statusToken).toMatchObject({
        type: TOKEN_TYPE_STATUS,
        title: TOKEN_TITLE_STATUS,
        icon: 'status',
        token: expect.any(Function),
        unique: true,
      });
    });

    it('excludes status token when feature is enabled and epic lists', async () => {
      await mountComponent({
        hasStatusFeature: true,
        isGroup: true,
      });
      await waitForPromises();

      const statusToken = findToken(TOKEN_TYPE_STATUS);

      expect(statusToken).toBeUndefined();
    });

    it('excludes status token when feature is enabled and is service desk list', async () => {
      await mountComponent({ hasStatusFeature: true, workItemType: WORK_ITEM_TYPE_NAME_TICKET });
      await waitForPromises();

      expect(findToken(TOKEN_TYPE_STATUS)).toBeUndefined();
    });
  });
});
