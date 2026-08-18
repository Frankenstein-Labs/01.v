import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import WorkItemDates from 'ee/work_items/components/work_item_dates.vue';
import WorkItemProgress from 'ee/work_items/components/work_item_progress.vue';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import WorkItemWeight from 'ee/work_items/components/work_item_weight.vue';
import WorkItemIteration from 'ee/work_items/components/work_item_iteration.vue';
import WorkItemColor from 'ee/work_items/components/work_item_color.vue';
import WorkItemCustomFields from 'ee/work_items/components/work_item_custom_fields.vue';
import WorkItemStatus from 'ee/work_items/components/work_item_status.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  epicType,
  mockParticipantWidget,
  allowedParentTypesResponse,
} from 'jest/work_items/mock_data';
import WorkItemParent from '~/work_items/components/work_item_parent.vue';
import WorkItemAttributesWrapper from '~/work_items/components/work_item_attributes_wrapper.vue';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import workItemParticipantsQuery from '~/work_items/graphql/work_item_participants.query.graphql';
import updateWorkItemMutation from '~/work_items/graphql/update_work_item.mutation.graphql';
import workItemUpdatedSubscription from '~/work_items/graphql/work_item_updated.subscription.graphql';
import getAllowedWorkItemParentTypes from '~/work_items/graphql/work_item_allowed_parent_types.query.graphql';
import { mockWorkItemStatus, workItemResponseFactory } from '../mock_data';

describe('EE WorkItemAttributesWrapper component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const workItemQueryResponse = workItemResponseFactory({
    canUpdate: true,
    canDelete: true,
    participantsWidgetPresent: false,
  });
  const workItemParticipantsQueryResponse = {
    data: {
      namespace: {
        __typename: 'Namespace',
        id: workItemQueryResponse.data.workItem.namespace.id,
        workItem: {
          id: workItemQueryResponse.data.workItem.id,
          widgets: [...workItemQueryResponse.data.workItem.widgets, mockParticipantWidget],
        },
      },
    },
  };
  const workItemParticipantsQuerySuccessHandler = jest
    .fn()
    .mockResolvedValue(workItemParticipantsQueryResponse);

  const successHandler = jest.fn().mockResolvedValue(workItemQueryResponse);
  const workItemUpdatedSubscriptionHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemUpdated: null } });
  const allowedParentTypesHandler = jest.fn().mockResolvedValue(allowedParentTypesResponse);

  const findWorkItemIteration = () => wrapper.findComponent(WorkItemIteration);
  const findWorkItemWeight = () => wrapper.findComponent(WorkItemWeight);
  const findWorkItemProgress = () => wrapper.findComponent(WorkItemProgress);
  const findWorkItemColor = () => wrapper.findComponent(WorkItemColor);
  const findWorkItemHealthStatus = () => wrapper.findComponent(WorkItemHealthStatus);
  const findWorkItemDates = () => wrapper.findComponent(WorkItemDates);
  const findWorkItemCustomFields = () => wrapper.findComponent(WorkItemCustomFields);
  const findWorkItemCustomStatus = () => wrapper.findComponent(WorkItemStatus);

  const createComponent = ({
    workItem = workItemQueryResponse.data.workItem,
    handler = successHandler,
    confidentialityMock = [updateWorkItemMutation, jest.fn()],
    featureFlags = {},
    hasSubepicsFeature = true,
    workItemParticipantsQueryHandler = workItemParticipantsQuerySuccessHandler,
    groupPath = 'flightjs',
  } = {}) => {
    wrapper = shallowMount(WorkItemAttributesWrapper, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, handler],
        [workItemUpdatedSubscription, workItemUpdatedSubscriptionHandler],
        [workItemParticipantsQuery, workItemParticipantsQueryHandler],
        [getAllowedWorkItemParentTypes, allowedParentTypesHandler],
        confidentialityMock,
      ]),
      propsData: {
        isGroup: false,
        fullPath: 'group/project',
        workItem,
        groupPath,
      },
      provide: {
        hasSubepicsFeature,
        issuesSettings: '/groups/test-project-path/-/settings/issues',
        glFeatures: featureFlags,
        getWorkItemTypeConfiguration: jest.fn().mockReturnValue({ widgetDefinitions: [] }),
      },
      stubs: {
        WorkItemStatus,
      },
    });
  };

  describe('iteration widget', () => {
    describe.each`
      description                               | iterationWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}                | ${true}
      ${'when widget is not returned from API'} | ${false}               | ${false}
    `('$description', ({ iterationWidgetPresent, exists }) => {
      it(`${
        iterationWidgetPresent ? 'renders' : 'does not render'
      } iteration component`, async () => {
        const response = workItemResponseFactory({ iterationWidgetPresent });
        createComponent({ workItem: response.data.workItem });
        await waitForPromises();

        expect(findWorkItemIteration().exists()).toBe(exists);
      });
    });

    describe('when features.iteration is present', () => {
      beforeEach(async () => {
        createComponent({
          workItem: {
            ...workItemResponseFactory({ iterationWidgetPresent: false }).data.workItem,
            features: {
              iteration: {
                iteration: null,
              },
            },
          },
        });

        await waitForPromises();
      });

      it('renders the iteration component', () => {
        expect(findWorkItemIteration().exists()).toBe(true);
      });
    });

    it('emits an error event to the wrapper', async () => {
      createComponent();
      await waitForPromises();
      const updateError = 'Failed to update';

      findWorkItemIteration().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual(expect.arrayContaining([[updateError]]));
    });
  });

  describe('weight widget', () => {
    it('allows widget to render if it exists', async () => {
      const response = workItemResponseFactory({ weightWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });

      await waitForPromises();

      expect(findWorkItemWeight().exists()).toBe(true);
    });

    it('hides widget if data doesn"t exist', async () => {
      const response = workItemResponseFactory({ weightWidgetPresent: false });
      createComponent({ workItem: response.data.workItem });

      await waitForPromises();

      expect(findWorkItemWeight().exists()).toBe(false);
    });

    it('renders when features.weight is present', async () => {
      createComponent({
        workItem: {
          ...workItemResponseFactory({ weightWidgetPresent: false }).data.workItem,
          features: {
            weight: {
              weight: null,
              rolledUpWeight: null,
              rolledUpCompletedWeight: null,
            },
          },
        },
      });

      await waitForPromises();

      expect(findWorkItemWeight().exists()).toBe(true);
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ weightWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      const updateError = 'Failed to update';

      await waitForPromises();

      findWorkItemWeight().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual(
        expect.arrayContaining([expect.arrayContaining([updateError])]),
      );
    });
  });

  describe('health status widget', () => {
    describe.each`
      description                               | healthStatusWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}                   | ${true}
      ${'when widget is not returned from API'} | ${false}                  | ${false}
    `('$description', ({ healthStatusWidgetPresent, exists }) => {
      it(`${
        healthStatusWidgetPresent ? 'renders' : 'does not render'
      } healthStatus component`, async () => {
        const response = workItemResponseFactory({ healthStatusWidgetPresent });
        createComponent({ workItem: response.data.workItem });
        await waitForPromises();

        expect(findWorkItemHealthStatus().exists()).toBe(exists);
      });
    });

    it('renders WorkItemHealthStatus', async () => {
      createComponent();
      await waitForPromises();

      expect(findWorkItemHealthStatus().exists()).toBe(true);
    });

    describe('when features.healthStatus is present', () => {
      beforeEach(async () => {
        createComponent({
          workItem: {
            ...workItemResponseFactory({ healthStatusWidgetPresent: false }).data.workItem,
            features: {
              healthStatus: {
                healthStatus: null,
                rolledUpHealthStatus: [],
              },
            },
          },
        });

        await waitForPromises();
      });

      it('renders the health status component', () => {
        expect(findWorkItemHealthStatus().exists()).toBe(true);
      });
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ healthStatusWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      await waitForPromises();
      const updateError = 'Failed to update';

      findWorkItemHealthStatus().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual(expect.arrayContaining([[updateError]]));
    });
  });

  describe('progress widget', () => {
    describe.each`
      description                               | progressWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}               | ${true}
      ${'when widget is not returned from API'} | ${false}              | ${false}
    `('$description', ({ progressWidgetPresent, exists }) => {
      it(`${progressWidgetPresent ? 'renders' : 'does not render'} progress component`, async () => {
        const response = workItemResponseFactory({ progressWidgetPresent });
        createComponent({ workItem: response.data.workItem });
        await waitForPromises();

        expect(findWorkItemProgress().exists()).toBe(exists);
      });
    });

    it('renders WorkItemProgress', async () => {
      createComponent();

      await waitForPromises();

      expect(findWorkItemProgress().exists()).toBe(true);
    });

    describe('when features.progress is present', () => {
      beforeEach(async () => {
        createComponent({
          workItem: {
            ...workItemResponseFactory({ progressWidgetPresent: false }).data.workItem,
            features: {
              progress: {
                progress: 0,
                updatedAt: null,
              },
            },
          },
        });

        await waitForPromises();
      });

      it('renders the progress component', () => {
        expect(findWorkItemProgress().exists()).toBe(true);
      });
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ progressWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      await waitForPromises();
      const updateError = 'Failed to update';

      findWorkItemProgress().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual(expect.arrayContaining([[updateError]]));
    });
  });

  describe('color widget', () => {
    describe.each`
      description                               | colorWidgetPresent | exists
      ${'when widget is returned from API'}     | ${true}            | ${true}
      ${'when widget is not returned from API'} | ${false}           | ${false}
    `('$description', ({ colorWidgetPresent, exists }) => {
      it(`${colorWidgetPresent ? 'renders' : 'does not render'} color component`, async () => {
        const response = workItemResponseFactory({ colorWidgetPresent });

        createComponent({ workItem: response.data.workItem });
        await waitForPromises();

        expect(findWorkItemColor().exists()).toBe(exists);
      });
    });

    it('renders WorkItemColor', async () => {
      createComponent();

      await waitForPromises();

      expect(findWorkItemColor().exists()).toBe(true);
    });

    describe('when features.color is present', () => {
      beforeEach(async () => {
        createComponent({
          workItem: {
            ...workItemResponseFactory({ colorWidgetPresent: false }).data.workItem,
            features: {
              color: {
                color: '#1068bf',
                textColor: '#FFFFFF',
              },
            },
          },
        });

        await waitForPromises();
      });

      it('renders the color component', () => {
        expect(findWorkItemColor().exists()).toBe(true);
      });
    });

    it('emits an error event to the wrapper', async () => {
      const response = workItemResponseFactory({ colorWidgetPresent: true });
      createComponent({ workItem: response.data.workItem });
      await waitForPromises();
      const updateError = 'Failed to update';

      findWorkItemColor().vm.$emit('error', updateError);
      await nextTick();

      expect(wrapper.emitted('error')).toEqual(expect.arrayContaining([[updateError]]));
    });
  });

  describe('parent widget', () => {
    it.each`
      description                                       | hasSubepicsFeature | exists
      ${'renders when subepics is available'}           | ${true}            | ${true}
      ${'does not render when subepics is unavailable'} | ${false}           | ${false}
    `('$description', async ({ hasSubepicsFeature, exists }) => {
      const response = workItemResponseFactory({ workItemType: epicType });
      createComponent({ workItem: response.data.workItem, hasSubepicsFeature });
      await waitForPromises();

      expect(wrapper.findComponent(WorkItemParent).exists()).toBe(exists);
    });
  });

  describe('rolledup dates widget', () => {
    const createComponentWithRolledupDates = async () => {
      const response = workItemResponseFactory({
        datesWidgetPresent: true,
        workItemType: epicType,
      });

      createComponent({
        workItem: response.data.workItem,
        handler: jest.fn().mockResolvedValue(workItemQueryResponse),
        featureFlags: {},
      });

      await waitForPromises();
    };

    it('renders rolledup dates widget', async () => {
      await createComponentWithRolledupDates();

      expect(findWorkItemDates().exists()).toBe(true);
    });
  });

  describe('custom fields widget', () => {
    it('renders custom fields widget', async () => {
      createComponent();
      await waitForPromises();

      expect(findWorkItemCustomFields().exists()).toBe(true);
    });

    describe('when features.customFields is present', () => {
      beforeEach(async () => {
        createComponent({
          workItem: {
            ...workItemResponseFactory({ customFieldsWidgetPresent: false }).data.workItem,
            features: {
              customFields: {
                customFieldValues: [],
              },
            },
          },
        });

        await waitForPromises();
      });

      it('renders the custom fields widget', () => {
        expect(findWorkItemCustomFields().exists()).toBe(true);
      });
    });
  });

  describe('status widget', () => {
    it('renders when widget is present and license feature is available', async () => {
      const response = workItemResponseFactory({ statusWidgetPresent: true });
      createComponent({
        workItem: response.data.workItem,
      });
      await waitForPromises();

      expect(findWorkItemCustomStatus().exists()).toBe(true);
    });

    it('does not render when widget is not present', async () => {
      createComponent();
      await waitForPromises();

      expect(findWorkItemCustomStatus().exists()).toBe(false);
    });

    describe('when features.status is present', () => {
      beforeEach(async () => {
        createComponent({
          workItem: {
            ...workItemResponseFactory({ statusWidgetPresent: false }).data.workItem,
            features: {
              status: {
                status: mockWorkItemStatus,
              },
            },
          },
        });

        await waitForPromises();
      });

      it('renders the status component', () => {
        expect(findWorkItemCustomStatus().exists()).toBe(true);
      });
    });
  });
});
