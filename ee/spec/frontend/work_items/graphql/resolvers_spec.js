import createMockApollo from 'helpers/mock_apollo_helper';
import { updateNewWorkItemCache } from '~/work_items/graphql/resolvers';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import updateNewWorkItemMutation from '~/work_items/graphql/update_new_work_item.mutation.graphql';
import {
  WIDGET_TYPE_COLOR,
  WIDGET_TYPE_START_AND_DUE_DATE,
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_ITERATION,
  WIDGET_TYPE_WEIGHT,
  WIDGET_TYPE_CUSTOM_FIELDS,
  WIDGET_TYPE_STATUS,
  CREATION_CONTEXT_LIST_ROUTE,
} from '~/work_items/constants';
import {
  createWorkItemQueryResponse,
  createWorkItemQueryResponseWithFeatures,
  customFieldsWidgetResponseFactory,
  mockWorkItemStatus,
} from '../mock_data';

describe('EE work items graphql resolvers', () => {
  describe('updateNewWorkItemCache', () => {
    let mockApolloClient;

    const fullPath = 'fullPath';
    const fullPathWithId = 'fullPath-issue-id';
    const iid = 'new-work-item-iid';
    const mockLocalIteration = {
      __typename: 'Iteration',
      id: 'gid://gitlab/Iteration/46697',
      title: null,
      startDate: '2024-08-26',
      dueDate: '2024-09-01',
      webUrl: 'http://127.0.0.1:3000/groups/flightjs/-/iterations/46697',
      iterationCadence: {
        __typename: 'IterationCadence',
        id: 'gid://gitlab/Iterations::Cadence/5042',
        title:
          'Tenetur voluptatem necessitatibus velit natus et ut animi deleniti adipisci voluptas.',
      },
    };

    const mutate = (input) => {
      mockApolloClient.mutate({
        mutation: updateNewWorkItemMutation,
        variables: {
          input: {
            workItemType: 'issue',
            fullPath,
            context: CREATION_CONTEXT_LIST_ROUTE,
            ...input,
          },
        },
      });
    };

    const query = async (widgetName = null) => {
      const queryResult = await mockApolloClient.query({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid, useWorkItemFeatures: false },
      });

      if (widgetName == null) return queryResult.data.namespace.workItem;

      return queryResult.data.namespace.workItem.widgets.find(({ type }) => type === widgetName);
    };

    const queryWithFeatures = async (featureName = null) => {
      const queryResult = await mockApolloClient.query({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid, useWorkItemFeatures: true },
      });

      if (featureName == null) return queryResult.data.namespace.workItem;

      return queryResult.data.namespace.workItem.features[featureName];
    };

    beforeEach(() => {
      const mockApollo = createMockApollo([], {
        Mutation: {
          updateNewWorkItem(_, { input }, { cache }) {
            updateNewWorkItemCache(input, cache);
          },
        },
      });
      mockApollo.clients.defaultClient.cache.writeQuery({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid, useWorkItemFeatures: true },
        data: createWorkItemQueryResponseWithFeatures([customFieldsWidgetResponseFactory()]).data,
      });

      mockApollo.clients.defaultClient.cache.writeQuery({
        query: workItemByIidQuery,
        variables: { fullPath: fullPathWithId, iid, useWorkItemFeatures: false },
        data: createWorkItemQueryResponse([customFieldsWidgetResponseFactory()]).data,
      });
      mockApolloClient = mockApollo.clients.defaultClient;
    });

    describe('title input', () => {
      it('updates title when added', async () => {
        await mutate({ title: 'Issue 1' });

        const queryResult = await query();
        expect(queryResult.title).toBe('Issue 1');
      });

      it('updates title if it becomes empty', async () => {
        await mutate({ title: '' });

        const queryResult = await query();
        expect(queryResult.title).toBe('');
      });

      it('does not update title if undefined (another input was updated)', async () => {
        await mutate({ title: 'Issue 2' });

        const queryResult1 = await query();
        expect(queryResult1.title).toBe('Issue 2');

        await mutate({ title: undefined });

        const queryResult2 = await query();
        expect(queryResult2.title).toBe('Issue 2');
      });
    });

    describe('with healthStatus input', () => {
      it('updates health status', async () => {
        await mutate({ healthStatus: 'onTrack' });

        const queryResult = await query(WIDGET_TYPE_HEALTH_STATUS);
        expect(queryResult).toMatchObject({ healthStatus: 'onTrack' });
      });

      it('clears health status', async () => {
        await mutate({ healthStatus: null });

        const queryResult = await query(WIDGET_TYPE_HEALTH_STATUS);
        expect(queryResult).toMatchObject({ healthStatus: null });
      });
    });

    describe('with color input', () => {
      it('updates color', async () => {
        await mutate({ color: '#000' });

        const queryResult = await query(WIDGET_TYPE_COLOR);
        expect(queryResult).toMatchObject({ color: '#000' });
      });
    });

    describe('with rolledUpDates input', () => {
      it('updates rolledUpDates', async () => {
        await mutate({
          rolledUpDates: {
            isFixed: true,
            rollUp: true,
            dueDate: '2024-02-02',
            startDate: '2023-12-22',
          },
        });

        const queryResult = await query(WIDGET_TYPE_START_AND_DUE_DATE);
        expect(queryResult).toMatchObject({
          isFixed: true,
          rollUp: true,
          dueDate: '2024-02-02',
          startDate: '2023-12-22',
        });
      });
    });

    describe('with iteration input', () => {
      it('updates iteration', async () => {
        await mutate({
          iteration: mockLocalIteration,
        });

        const queryResult = await query(WIDGET_TYPE_ITERATION);
        expect(queryResult).toMatchObject({
          iteration: mockLocalIteration,
        });
      });
    });

    describe('with weight input', () => {
      it('updates weight if value is a number', async () => {
        await mutate({ weight: 2 });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: 2 });
      });

      it('updates weight if value is number 0', async () => {
        await mutate({ weight: 0 });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: 0 });
      });

      it('does not update weight if value is not changed/undefined', async () => {
        await mutate({ weight: undefined });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: 2 });
      });

      it('updates weight if cleared', async () => {
        await mutate({ weight: null });

        const queryResult = await query(WIDGET_TYPE_WEIGHT);
        expect(queryResult).toMatchObject({ weight: null });
      });
    });

    describe('with custom field input', () => {
      it('updates number custom field properly', async () => {
        const customFieldInput = {
          id: '1-number',
          value: 5,
        };

        await mutate({ customField: customFieldInput });

        const queryResult = await query(WIDGET_TYPE_CUSTOM_FIELDS);

        // Find the specific custom field in the customFieldValues array
        const updatedField = queryResult.customFieldValues.find(
          (field) => field.customField.id === '1-number',
        );

        expect(updatedField.customField.fieldType).toBe('NUMBER');
        expect(updatedField.value).toBe(5);
      });

      it('updates text custom field properly', async () => {
        const customFieldInput = {
          id: '1-text',
          value: 'Sample text',
        };

        await mutate({ customField: customFieldInput });

        const queryResult = await query(WIDGET_TYPE_CUSTOM_FIELDS);

        // Find the specific custom field in the customFieldValues array
        const updatedField = queryResult.customFieldValues.find(
          (field) => field.customField.id === '1-text',
        );

        expect(updatedField.customField.fieldType).toBe('TEXT');
        expect(updatedField.value).toBe('Sample text');
      });

      it('updates single select custom field properly', async () => {
        const customFieldInput = {
          id: '1-select',
          selectedOptions: [
            {
              id: 'select-1',
              value: 'Option 1',
            },
          ],
        };

        await mutate({ customField: customFieldInput });

        const queryResult = await query(WIDGET_TYPE_CUSTOM_FIELDS);

        // Find the specific custom field in the customFieldValues array
        const updatedField = queryResult.customFieldValues.find(
          (field) => field.customField.id === '1-select',
        );

        expect(updatedField.customField.fieldType).toBe('SINGLE_SELECT');
        expect(updatedField.selectedOptions[0].id).toBe('select-1');
        expect(updatedField.selectedOptions[0].value).toBe('Option 1');
      });

      it('updates multi select custom field properly', async () => {
        const customFieldInput = {
          id: '1-multi-select',
          selectedOptions: [
            {
              id: 'select-1',
              value: 'Option 1',
            },
            {
              id: 'select-2',
              value: 'Option 2',
            },
          ],
        };

        await mutate({ customField: customFieldInput });

        const queryResult = await query(WIDGET_TYPE_CUSTOM_FIELDS);

        // Find the specific custom field in the customFieldValues array
        const updatedField = queryResult.customFieldValues.find(
          (field) => field.customField.id === '1-multi-select',
        );

        expect(updatedField.customField.fieldType).toBe('MULTI_SELECT');
        expect(updatedField.selectedOptions[0].id).toBe('select-1');
        expect(updatedField.selectedOptions[0].value).toBe('Option 1');
        expect(updatedField.selectedOptions[1].id).toBe('select-2');
        expect(updatedField.selectedOptions[1].value).toBe('Option 2');
      });

      it('does not update custom field if id doesnt match', async () => {
        const customFieldInput = {
          id: '1-invalid',
          selectedOptions: [
            {
              id: 'select-1',
              value: 'Option 1',
            },
            {
              id: 'select-2',
              value: 'Option 2',
            },
          ],
        };

        await mutate({ customField: customFieldInput });

        const queryResult = await query(WIDGET_TYPE_CUSTOM_FIELDS);

        // Find the specific custom field in the customFieldValues array
        const updatedField = queryResult.customFieldValues.find(
          (field) => field.customField.id === '1-invalid',
        );

        expect(updatedField).toBe(undefined);
      });
    });

    describe('with custom status input', () => {
      it('updates status', async () => {
        await mutate({
          status: mockWorkItemStatus,
        });

        const queryResult = await query(WIDGET_TYPE_STATUS);
        expect(queryResult).toMatchObject({
          status: mockWorkItemStatus,
        });
      });
    });

    describe('with useWorkItemFeatures enabled', () => {
      const mutateWithFeatures = (input) => {
        return mutate({ useWorkItemFeatures: true, ...input });
      };

      describe('with healthStatus input', () => {
        it('updates health status via features', async () => {
          await mutateWithFeatures({ healthStatus: 'onTrack' });

          const result = await queryWithFeatures('healthStatus');
          expect(result).toMatchObject({ healthStatus: 'onTrack' });
        });

        it('clears health status via features', async () => {
          await mutateWithFeatures({ healthStatus: null });

          const result = await queryWithFeatures('healthStatus');
          expect(result).toMatchObject({ healthStatus: null });
        });
      });

      describe('with iteration input', () => {
        it('updates iteration via features', async () => {
          await mutateWithFeatures({ iteration: mockLocalIteration });

          const result = await queryWithFeatures('iteration');
          expect(result).toMatchObject({ iteration: mockLocalIteration });
        });
      });

      describe('with weight input', () => {
        it('updates weight via features', async () => {
          await mutateWithFeatures({ weight: 5 });

          const result = await queryWithFeatures('weight');
          expect(result).toMatchObject({ weight: 5 });
        });

        it('clears weight via features', async () => {
          await mutateWithFeatures({ weight: null });

          const result = await queryWithFeatures('weight');
          expect(result).toMatchObject({ weight: null });
        });

        it('does not update weight if undefined', async () => {
          await mutateWithFeatures({ weight: undefined });

          const result = await queryWithFeatures('weight');
          expect(result).toMatchObject({ weight: 2 });
        });
      });

      describe('with status input', () => {
        it('updates status via features', async () => {
          await mutateWithFeatures({ status: mockWorkItemStatus });

          const result = await queryWithFeatures('status');
          expect(result).toMatchObject({ status: mockWorkItemStatus });
        });
      });

      describe('with title input', () => {
        it('still updates title directly on workItem', async () => {
          await mutateWithFeatures({ title: 'Features Title' });

          const result = await queryWithFeatures();
          expect(result).toMatchObject({ title: 'Features Title' });
        });
      });
    });
  });
});
