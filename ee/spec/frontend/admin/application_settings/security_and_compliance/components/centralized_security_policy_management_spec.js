import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { visitUrl } from '~/lib/utils/url_utility';
import Api from 'ee/api';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';
import CentralizedSecurityPolicyManagement from 'ee/admin/application_settings/security_and_compliance/components/centralized_security_policy_management.vue';
import ConfirmationModal from 'ee/admin/application_settings/security_and_compliance/components/confirmation_modal.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));
jest.mock('ee/api');

const mockGroupsResponse = {
  data: {
    groups: {
      nodes: [
        {
          id: 'gid://gitlab/Group/1',
          name: 'Group 1',
          fullName: 'Group 1',
          fullPath: 'group-1',
          avatarUrl: 'avatar1.png',
        },
        {
          id: 'gid://gitlab/Group/2',
          name: 'Group 2',
          fullName: 'Group 2',
          fullPath: 'group-2',
          avatarUrl: 'avatar2.png',
        },
      ],
      pageInfo: {
        __typename: 'PageInfo',
        hasNextPage: false,
        hasPreviousPage: false,
        endCursor: null,
        startCursor: null,
      },
    },
  },
};

const newGroupPath = 'path/to/groups/new';

describe('CentralizedSecurityPolicyManagement', () => {
  let wrapper;
  let requestHandler;
  let showModalWindowSpy;
  let glTooltipDirectiveMock;

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;
    return createMockApollo([[getGroups, requestHandler]]);
  };

  const createComponent = ({
    props = {},
    handler = jest.fn().mockResolvedValue(mockGroupsResponse),
  } = {}) => {
    glTooltipDirectiveMock = jest.fn();
    showModalWindowSpy = jest.fn();
    wrapper = shallowMountExtended(CentralizedSecurityPolicyManagement, {
      apolloProvider: createMockApolloProvider(handler),
      directives: {
        GlTooltip: glTooltipDirectiveMock,
      },
      propsData: {
        centralizedSecurityPolicyGroupLocked: false,
        formId: 'test-form',
        newGroupPath,
        ...props,
      },
      stubs: {
        ConfirmationModal: stubComponent(ConfirmationModal, {
          methods: {
            showModalWindow: showModalWindowSpy,
          },
        }),
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findModal = () => wrapper.findComponent(ConfirmationModal);
  const findSaveButton = () => wrapper.findComponentByTestId('save-button');
  const findCreateGroupButton = () => wrapper.findComponentByTestId('create-group-button');

  beforeEach(() => {
    // Mock DOM element for form submission
    document.getElementById = jest.fn().mockReturnValue({
      submit: jest.fn(),
    });
  });

  afterEach(() => {
    Api.updateCompliancePolicySettings.mockReset();
  });

  describe('rendering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the collapsible listbox with correct props', () => {
      const listbox = findListbox();

      expect(listbox.exists()).toBe(true);
      expect(listbox.props('searchable')).toBe(true);
      expect(listbox.props('isCheckCentered')).toBe(true);
      expect(listbox.props('toggleText')).toBe('Select a group');
    });

    it('renders save button', () => {
      expect(findSaveButton().exists()).toBe(true);
      expect(findSaveButton().props('disabled')).toBe(false);
      expect(glTooltipDirectiveMock.mock.calls[0][1].value.disabled).toBe(true);
    });
  });

  describe('group selection', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('updates toggle text when a group is selected', async () => {
      findListbox().vm.$emit('select', 1);
      await nextTick();

      expect(findListbox().props('toggleText')).toBe('Group 1');
    });

    it('updates selected group when user selects from listbox', async () => {
      findListbox().vm.$emit('select', 1);
      await nextTick();
      expect(findListbox().props('selected')).toBe(1);
    });
  });

  describe('search functionality', () => {
    beforeEach(async () => {
      jest.useFakeTimers({ legacyFakeTimers: false });
      createComponent();
      await waitForPromises();
    });

    afterEach(() => {
      jest.useFakeTimers({ legacyFakeTimers: true });
    });

    it('handles search input with debouncing', async () => {
      const searchTerm = 'test search';
      findListbox().vm.$emit('search', searchTerm);
      expect(requestHandler).toHaveBeenCalledTimes(1);
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalledTimes(2);
      expect(requestHandler).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({ search: searchTerm }),
      );
    });
  });

  describe('infinite scroll', () => {
    const mockResponseWithNextPage = {
      data: {
        groups: {
          nodes: mockGroupsResponse.data.groups.nodes,
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: 'cursor2',
          },
        },
      },
    };

    it('shows infinite scroll when there are more pages', async () => {
      createComponent({ handler: jest.fn().mockResolvedValue(mockResponseWithNextPage) });
      await waitForPromises();
      expect(findListbox().props('infiniteScroll')).toBe(true);
    });

    it('triggers load more when bottom is reached', async () => {
      const mockSecondResponse = {
        data: {
          groups: {
            nodes: [{ ...mockGroupsResponse.data.groups.nodes[0], id: 'gid://gitlab/Group/3' }],
            pageInfo: {
              __typename: 'PageInfo',
              hasNextPage: false,
              hasPreviousPage: true,
              startCursor: 'cursor2',
              endCursor: null,
            },
          },
        },
      };

      createComponent({
        handler: jest
          .fn()
          .mockResolvedValueOnce(mockResponseWithNextPage)
          .mockResolvedValueOnce(mockSecondResponse),
      });
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalledTimes(1);
      findListbox().vm.$emit('bottom-reached');
      expect(requestHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('loading states', () => {
    it('shows loading state during Apollo query', () => {
      createComponent();

      expect(findListbox().props('loading')).toBe(true);
    });

    it('disables save button during loading', () => {
      createComponent();

      expect(findSaveButton().props('disabled')).toBe(true);
    });
  });

  describe('save functionality', () => {
    beforeEach(() => {
      Api.updateCompliancePolicySettings.mockResolvedValue({});
    });

    it('shows confirmation modal on save', async () => {
      createComponent();
      await waitForPromises();

      // Select a group first
      findListbox().vm.$emit('select', 1);
      await nextTick();

      findSaveButton().vm.$emit('click');
      expect(showModalWindowSpy).toHaveBeenCalled();
      expect(Api.updateCompliancePolicySettings).not.toHaveBeenCalled();
    });

    it('calls API and submits form when save button is clicked with selected group', async () => {
      createComponent();
      await waitForPromises();

      // Select a group first
      findListbox().vm.$emit('select', 1);
      await nextTick();

      findModal().vm.$emit('change');

      expect(Api.updateCompliancePolicySettings).toHaveBeenCalledWith({
        csp_namespace_id: 1,
      });
    });

    it('calls API and submits form when save button is clicked with no group selected', async () => {
      createComponent();
      await waitForPromises();

      // Select a group first
      findListbox().vm.$emit('reset');
      await nextTick();

      findModal().vm.$emit('change');

      expect(Api.updateCompliancePolicySettings).toHaveBeenCalledWith({
        csp_namespace_id: null,
      });
    });

    it('shows loading state during save operation', async () => {
      createComponent();
      await waitForPromises();

      // Select a group first
      findListbox().vm.$emit('select', 1);
      await nextTick();

      // Mock a pending API call
      // Api.updateCompliancePolicySettings.mockImplementation(() => new Promise(() => {}));

      await findModal().vm.$emit('change');

      expect(findListbox().props('loading')).toBe(true);
      expect(findSaveButton().props('disabled')).toBe(true);
    });

    it('disables save button if 10min have not passed since last change', async () => {
      const props = {
        centralizedSecurityPolicyGroupLocked: true,
      };
      createComponent({ props });
      await waitForPromises();
      expect(findSaveButton().props('disabled')).toBe(true);
      expect(glTooltipDirectiveMock.mock.calls[0][1].value.disabled).toBe(false);

      findSaveButton().vm.$emit('click');
      expect(showModalWindowSpy).not.toHaveBeenCalled();
    });
  });

  describe('creating a new group', () => {
    it('navigates to the new group page when the footer is clicked', async () => {
      createComponent();
      await waitForPromises();
      await findCreateGroupButton().vm.$emit('click');
      expect(visitUrl).toHaveBeenCalledWith(newGroupPath);
    });
  });

  describe('lifecycle hooks', () => {
    it('cancels debounced search when component is destroyed', async () => {
      createComponent();
      await waitForPromises();

      const cancelSpy = jest.spyOn(wrapper.vm.handleSearch, 'cancel');

      // Stop Apollo queries before destroying to prevent console errors
      await wrapper.vm.$apollo.queries.groups.stop();
      wrapper.destroy();

      expect(cancelSpy).toHaveBeenCalled();
    });
  });
});
