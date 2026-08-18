import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CreateWorkItem from '~/work_items/components/create_work_item.vue';
import WorkItemTitle from '~/work_items/components/work_item_title.vue';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import WorkItemColor from 'ee/work_items/components/work_item_color.vue';
import WorkItemIteration from 'ee/work_items/components/work_item_iteration.vue';
import WorkItemWeight from 'ee/work_items/components/work_item_weight.vue';
import WorkItemDates from 'ee/work_items/components/work_item_dates.vue';
import WorkItemStatus from 'ee/work_items/components/work_item_status.vue';
import WorkItemParent from '~/work_items/components/work_item_parent.vue';
import WorkItemCustomFields from 'ee/work_items/components/work_item_custom_fields.vue';
import WorkItemNamespaceListbox from '~/work_items/components/shared/work_item_namespace_listbox.vue';
import {
  CREATION_CONTEXT_LIST_ROUTE,
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_ISSUE,
  WORK_ITEM_TYPE_NAME_TASK,
} from '~/work_items/constants';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import createWorkItemMutation from '~/work_items/graphql/create_work_item.mutation.graphql';
import workItemTypesConfigurationQuery from '~/work_items/graphql/work_item_types_configuration.query.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import setWindowLocation from 'helpers/set_window_location_helper';
import { resolvers } from '~/graphql_shared/issuable_client';
import {
  createWorkItemMutationResponse,
  createWorkItemQueryResponse,
  customFieldsWidgetResponseFactory,
  mockWorkItemTypesConfigurationResponse,
  namespaceWorkItemsWithoutEpicSupport,
  namespaceWorkItemTypesQueryResponse,
} from '../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility', () => ({
  getParameterByName: jest.fn().mockReturnValue('22'),
  mergeUrlParams: jest.fn().mockReturnValue('/branches?state=all&search=%5Emain%24'),
  joinPaths: jest.fn(),
  setUrlParams: jest
    .fn()
    .mockReturnValue('/project/Project/-/settings/repository/branch_rules?branch=main'),
  setUrlFragment: jest.fn(),
  visitUrl: jest.fn().mockName('visitUrlMock'),
  getBaseURL: jest.fn().mockReturnValue('http://127.0.0.0:3000'),
  relativePathToAbsolute: jest.fn().mockImplementation((path) => path),
}));

describe('EE Create work item component', () => {
  const originalFeatures = gon.features;
  let wrapper;
  let mockApollo;

  const createWorkItemSuccessHandler = jest.fn().mockResolvedValue(createWorkItemMutationResponse);
  const workItemQuerySuccessHandler = jest
    .fn()
    .mockResolvedValue(createWorkItemQueryResponse([customFieldsWidgetResponseFactory()]));
  const namespaceWorkItemTypesHandler = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemTypesQueryResponse);
  const workItemTypesConfigurationHandler = jest
    .fn()
    .mockResolvedValue(mockWorkItemTypesConfigurationResponse);

  const findHealthStatusWidget = () => wrapper.findComponent(WorkItemHealthStatus);
  const findTitleInput = () => wrapper.findComponent(WorkItemTitle);
  const findIterationWidget = () => wrapper.findComponent(WorkItemIteration);
  const findWeightWidget = () => wrapper.findComponent(WorkItemWeight);
  const findColorWidget = () => wrapper.findComponent(WorkItemColor);
  const findDatesWidget = () => wrapper.findComponent(WorkItemDates);
  const findCustomFieldsWidget = () => wrapper.findComponent(WorkItemCustomFields);
  const findParentWidget = () => wrapper.findComponent(WorkItemParent);
  const findStatusWidget = () => wrapper.findComponent(WorkItemStatus);
  const findGroupProjectSelector = () => wrapper.findComponent(WorkItemNamespaceListbox);

  const updateWorkItemTitle = async (title = 'Test title') => {
    findTitleInput().vm.$emit('updateDraft', title);
    await nextTick();
    await waitForPromises();
  };

  const submitCreateForm = async () => {
    wrapper.find('form').trigger('submit');
    await waitForPromises();
  };

  const createComponent = ({
    props = {},
    mutationHandler = createWorkItemSuccessHandler,
    namespaceHandler = namespaceWorkItemTypesHandler,
    preselectedWorkItemType = WORK_ITEM_TYPE_NAME_EPIC,
  } = {}) => {
    mockApollo = createMockApollo(
      [
        [workItemByIidQuery, workItemQuerySuccessHandler],
        [createWorkItemMutation, mutationHandler],
        [namespaceWorkItemTypesQuery, namespaceHandler],
        [workItemTypesConfigurationQuery, workItemTypesConfigurationHandler],
      ],
      resolvers,
    );

    wrapper = shallowMount(CreateWorkItem, {
      apolloProvider: mockApollo,
      propsData: {
        fullPath: 'full-path',
        creationContext: CREATION_CONTEXT_LIST_ROUTE,
        preselectedWorkItemType,
        ...props,
      },
      provide: {
        groupPath: 'group-path',
        issuesSettings: '/groups/twitter/-/settings/issues',
      },
      stubs: {
        WorkItemStatus,
      },
    });
  };

  const mockCurrentUser = {
    id: 1,
    name: 'Administrator',
    username: 'root',
    avatar_url: 'avatar/url',
  };

  beforeEach(() => {
    gon.current_user_id = mockCurrentUser.id;
    gon.current_user_fullname = mockCurrentUser.name;
    gon.current_username = mockCurrentUser.username;
    gon.current_user_avatar_url = mockCurrentUser.avatar_url;
    gon.features = {};
  });

  afterAll(() => {
    gon.features = originalFeatures;
  });

  describe('Create work item widgets for Epic work item type', () => {
    beforeEach(async () => {
      createComponent({ preselectedWorkItemType: WORK_ITEM_TYPE_NAME_EPIC });
      await waitForPromises();
    });

    it('renders the work item health status widget', () => {
      expect(findHealthStatusWidget().exists()).toBe(true);
    });

    it('renders the work item color widget', () => {
      expect(findColorWidget().exists()).toBe(true);
    });

    it('renders the work item rolled up dates widget', () => {
      expect(findDatesWidget().exists()).toBe(true);
    });

    it('renders the work item parent widget', () => {
      expect(findParentWidget().exists()).toBe(true);
    });

    it('renders the work item custom field widget', () => {
      expect(findCustomFieldsWidget().exists()).toBe(true);
    });
  });

  describe('Create work item widgets for Issue work item type', () => {
    beforeEach(async () => {
      createComponent({ preselectedWorkItemType: WORK_ITEM_TYPE_NAME_ISSUE });
      await waitForPromises();
    });

    it('renders the work item health status widget', () => {
      expect(findHealthStatusWidget().exists()).toBe(true);
    });

    it('renders the work item iteration widget', () => {
      expect(findIterationWidget().exists()).toBe(true);
    });

    it('renders the work item weight widget', () => {
      expect(findWeightWidget().exists()).toBe(true);
    });

    it('renders the work item parent widget', () => {
      expect(findParentWidget().exists()).toBe(true);
      expect(findParentWidget().props('allowedParentTypesForNewWorkItem')).toEqual([
        {
          id: 'gid://gitlab/WorkItems::Type/8',
          name: 'Epic',
          __typename: 'WorkItemType',
        },
      ]);
    });

    it('renders the work item status widget', async () => {
      createComponent({
        preselectedWorkItemType: WORK_ITEM_TYPE_NAME_ISSUE,
      });
      await waitForPromises();

      expect(findStatusWidget().exists()).toBe(true);
    });

    it('renders the work item custom field widget', () => {
      expect(findCustomFieldsWidget().exists()).toBe(true);
    });
  });

  describe('Create work item widgets for Task work item type', () => {
    beforeEach(async () => {
      createComponent({ preselectedWorkItemType: WORK_ITEM_TYPE_NAME_TASK });
      await waitForPromises();
    });

    it('renders the work item iteration widget', () => {
      expect(findIterationWidget().exists()).toBe(true);
    });

    it('renders the work item weight widget', () => {
      expect(findWeightWidget().exists()).toBe(true);
    });

    it('renders the work item parent widget', () => {
      expect(findParentWidget().exists()).toBe(true);
      expect(findParentWidget().props('allowedParentTypesForNewWorkItem')).toEqual([
        { __typename: 'WorkItemType', id: 'gid://gitlab/WorkItems::Type/2', name: 'Incident' },
        { __typename: 'WorkItemType', id: 'gid://gitlab/WorkItems::Type/1', name: 'Issue' },
        { __typename: 'WorkItemType', id: 'gid://gitlab/WorkItems::Type/9', name: 'Ticket' },
      ]);
    });

    it('renders the work item status widget', async () => {
      createComponent({
        preselectedWorkItemType: WORK_ITEM_TYPE_NAME_TASK,
      });
      await waitForPromises();

      expect(findStatusWidget().exists()).toBe(true);
    });
  });

  describe('New work item for a vulnerability', () => {
    it('when not creating a vulnerability, does not pass resolve params to mutation', async () => {
      createComponent({ preselectedWorkItemType: WORK_ITEM_TYPE_NAME_ISSUE });
      await waitForPromises();

      await updateWorkItemTitle();
      await submitCreateForm();

      expect(createWorkItemSuccessHandler).not.toHaveBeenCalledWith({
        input: expect.objectContaining({
          vulnerabilityId: null,
        }),
      });
    });

    it('when creating issue from a vulnerability', async () => {
      setWindowLocation('?vulnerability_id=22');

      createComponent({ preselectedWorkItemType: WORK_ITEM_TYPE_NAME_ISSUE });
      await waitForPromises();

      await updateWorkItemTitle();
      await submitCreateForm();

      expect(createWorkItemSuccessHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            vulnerabilityId: 'gid://gitlab/Vulnerability/22',
          }),
        }),
      );
    });
  });

  describe('Creating work item with custom fields passes correct input to mutation', () => {
    const customFieldsNamespaceWorkItemTypesResponse = {
      ...namespaceWorkItemsWithoutEpicSupport,
      widgetDefinitions: [
        ...namespaceWorkItemsWithoutEpicSupport.data.namespace.workItemTypes.nodes[0]
          .widgetDefinitions,
        {
          type: 'CUSTOM_FIELDS',
          customFieldValues: [],
          __typename: 'WorkItemWidgetDefinitionCustomFields',
        },
      ],
      __typename: 'WorkItemType',
    };

    it('when creating issue with custom field values', async () => {
      const customNamespaceWorkItemTypesHandler = jest
        .fn()
        .mockResolvedValue(customFieldsNamespaceWorkItemTypesResponse);

      createComponent({
        preselectedWorkItemType: WORK_ITEM_TYPE_NAME_ISSUE,
        namespaceHandler: customNamespaceWorkItemTypesHandler,
      });
      await waitForPromises();

      await updateWorkItemTitle();
      await submitCreateForm();

      expect(createWorkItemSuccessHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            customFieldsWidget: [
              { customFieldId: '1-number', numberValue: 5 },
              { customFieldId: '1-text', textValue: 'Sample text' },
              { customFieldId: '1-select', selectedOptionIds: ['select-1'] },
              { customFieldId: '1-multi-select', selectedOptionIds: ['select-1', 'select-2'] },
            ],
          }),
        }),
      );
    });
  });

  describe('Group/project selector', () => {
    it('does not render when initiated from epics list', async () => {
      createComponent({
        props: { isGroup: true, isEpicsList: true },
      });
      await waitForPromises();

      expect(findGroupProjectSelector().exists()).toBe(false);
    });
  });
});
