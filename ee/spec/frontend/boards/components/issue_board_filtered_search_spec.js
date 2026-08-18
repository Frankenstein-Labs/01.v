import { shallowMount } from '@vue/test-utils';
import { orderBy } from 'lodash-es';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BoardFilteredSearch from 'ee/boards/components/board_filtered_search.vue';
import IssueBoardFilteredSearch from 'ee/boards/components/issue_board_filtered_search.vue';
import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';
import issueBoardFilters from 'ee/boards/issue_board_filters';
import { mockTokens } from '../mock_data';

Vue.use(VueApollo);
jest.mock('ee/boards/issue_board_filters');

describe('IssueBoardFilter', () => {
  let wrapper;

  const createComponent = ({
    hasCustomFieldsFeature = false,
    statusListsAvailable = false,
    hasStatusFeature = false,
    workItemTasksOnBoards = false,
    customFieldsData = [
      {
        fieldType: 'MULTI_SELECT',
        id: 'gid://gitlab/CustomField/12345',
        name: 'Issue only field',
        workItemTypes: [
          {
            id: 'gid://gitlab/WorkItemTypes/1',
            name: 'Issue',
          },
        ],
      },
    ],
  } = {}) => {
    const customFieldsQueryHandler = jest.fn().mockResolvedValue({
      data: {
        namespace: {
          id: 'gid://gitlab/Group/1',
          customFields: {
            count: customFieldsData.length,
            nodes: customFieldsData,
          },
        },
      },
    });

    wrapper = shallowMount(IssueBoardFilteredSearch, {
      propsData: {
        boardId: 'gid://gitlab/Board/1',
        filters: {},
      },
      apolloProvider: createMockApollo([[namespaceCustomFieldsQuery, customFieldsQueryHandler]]),
      provide: {
        isSignedIn: true,
        releasesFetchPath: '/releases',
        fullPath: 'gitlab-org',
        isGroupBoard: true,
        epicFeatureAvailable: true,
        iterationFeatureAvailable: true,
        healthStatusFeatureAvailable: true,
        hasCustomFieldsFeature,
        statusListsAvailable,
        hasStatusFeature,
        glFeatures: {
          workItemTasksOnBoards,
        },
      },
    });
  };

  let fetchLabelsSpy;
  let fetchIterationsSpy;
  beforeEach(() => {
    fetchLabelsSpy = jest.fn();
    fetchIterationsSpy = jest.fn();

    issueBoardFilters.mockReturnValue({
      fetchLabels: fetchLabelsSpy,
      fetchIterations: fetchIterationsSpy,
    });
  });

  describe('default', () => {
    beforeEach(() => {});

    it('finds BoardFilteredSearch', () => {
      createComponent();
      expect(wrapper.findComponent(BoardFilteredSearch).exists()).toBe(true);
    });

    it('passes the correct tokens to BoardFilteredSearch including epics', () => {
      createComponent();
      const tokens = mockTokens({
        fetchLabels: fetchLabelsSpy,
        fetchIterations: fetchIterationsSpy,
      });

      expect(wrapper.findComponent(BoardFilteredSearch).props('tokens')).toEqual(
        orderBy(tokens, ['title']),
      );
    });

    it('passes custom fields to BoardFilteredSearch', async () => {
      const tokens = mockTokens({
        fetchLabels: fetchLabelsSpy,
        fetchIterations: fetchIterationsSpy,
        hasCustomFieldsFeature: true,
      });

      createComponent({ hasCustomFieldsFeature: true });

      await waitForPromises();

      expect(wrapper.findComponent(BoardFilteredSearch).props('tokens')).toEqual(
        orderBy(tokens, ['title']),
      );
    });

    describe('status token', () => {
      it('passes Work item status token to BoardFilteredSearch when enabled', async () => {
        const tokens = mockTokens({
          fetchLabels: fetchLabelsSpy,
          fetchIterations: fetchIterationsSpy,
          showCustomStatusToken: true,
        });
        createComponent({
          statusListsAvailable: true,
          hasStatusFeature: true,
        });

        await waitForPromises();

        expect(wrapper.findComponent(BoardFilteredSearch).props('tokens')).toEqual(
          orderBy(tokens, ['title']),
        );
      });

      it('does not pass Work item status token to BoardFilteredSearch when feature disabled', async () => {
        const tokens = mockTokens({
          fetchLabels: fetchLabelsSpy,
          fetchIterations: fetchIterationsSpy,
          showCustomStatusToken: true,
        });
        createComponent({
          statusListsAvailable: false,
          hasStatusFeature: false,
        });

        await waitForPromises();

        expect(wrapper.findComponent(BoardFilteredSearch).props('tokens')).not.toEqual(
          orderBy(tokens, ['title']),
        );
      });
    });

    describe('task-only assigned custom field filter', () => {
      const taskOnlyCustomField = {
        id: 'gid://gitlab/Issuables::CustomField/55',
        name: 'Task only field',
        fieldType: 'SINGLE_SELECT',
        workItemTypes: [
          {
            id: 'gid://gitlab/WorkItemTypes/2',
            name: 'Task',
          },
        ],
      };

      const issueAndTaskCustomField = {
        id: 'gid://gitlab/Issuables::CustomField/59',
        name: 'Issue and Task field',
        fieldType: 'MULTI_SELECT',
        workItemTypes: [
          {
            id: 'gid://gitlab/WorkItemTypes/1',
            name: 'Issue',
          },
          {
            id: 'gid://gitlab/WorkItemTypes/2',
            name: 'Task',
          },
        ],
      };

      it('includes task-only custom field filter when `workItemTasksOnBoards` flag is enabled', async () => {
        createComponent({
          hasCustomFieldsFeature: true,
          workItemTasksOnBoards: true,
          customFieldsData: [taskOnlyCustomField, issueAndTaskCustomField],
        });

        await waitForPromises();

        const tokens = wrapper.findComponent(BoardFilteredSearch).props('tokens');
        const customFieldTokens = tokens.filter((token) => token.type.startsWith('custom-field'));

        expect(customFieldTokens).toHaveLength(2);
        expect(customFieldTokens.map((token) => token.title)).toEqual([
          'Issue and Task field',
          'Task only field',
        ]);
      });

      it('excludes task-only custom field filter when `workItemTasksOnBoards` flag is disabled', async () => {
        createComponent({
          hasCustomFieldsFeature: true,
          workItemTasksOnBoards: false,
          customFieldsData: [taskOnlyCustomField, issueAndTaskCustomField],
        });

        await waitForPromises();

        const tokens = wrapper.findComponent(BoardFilteredSearch).props('tokens');
        const customFieldTokens = tokens.filter((token) => token.type.startsWith('custom-field'));

        expect(customFieldTokens).toHaveLength(1);
        expect(customFieldTokens[0].title).toBe('Issue and Task field');
      });

      it('includes issue-only custom fields regardless of `workItemTasksOnBoards` flag', async () => {
        createComponent({
          hasCustomFieldsFeature: true,
          workItemTasksOnBoards: false,
        });

        await waitForPromises();

        const tokens = wrapper.findComponent(BoardFilteredSearch).props('tokens');
        const customFieldTokens = tokens.filter((token) => token.type.startsWith('custom-field'));

        expect(customFieldTokens).toHaveLength(1);
        expect(customFieldTokens[0].title).toBe('Issue only field');
      });
    });
  });
});
