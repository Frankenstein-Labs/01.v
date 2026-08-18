import { GlSearchBoxByType } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import searchUsersQuery from '~/graphql_shared/queries/workspace_autocomplete_users.query.graphql';
import searchUsersQueryOnMR from '~/graphql_shared/queries/project_autocomplete_users_with_mr_permissions.query.graphql';
import SidebarParticipant from '~/sidebar/components/assignees/sidebar_participant.vue';
import getIssueParticipantsQuery from '~/sidebar/queries/get_issue_participants.query.graphql';
import getMergeRequestParticipantsQuery from '~/sidebar/queries/get_mr_participants.query.graphql';
import UserSelect from '~/vue_shared/components/user_select/user_select.vue';
import {
  projectAutocompleteMembersResponse,
  searchAutocompleteResponseOnMR,
  participantsQueryResponse,
  mockUser1,
  mockUser2,
  mockDisabledUser,
} from 'jest/sidebar/mock_data';

Vue.use(VueApollo);

describe('User select dropdown - EE', () => {
  let wrapper;
  let fakeApollo;

  const findUnselectedParticipants = () => wrapper.findAllByTestId('unselected-participant');
  const findSelectedParticipants = () => wrapper.findAllByTestId('selected-participant');

  const participantsQueryHandlerSuccess = jest.fn().mockResolvedValue(participantsQueryResponse);

  const createComponent = ({
    props = {},
    searchQueryHandler = jest.fn().mockResolvedValue(projectAutocompleteMembersResponse),
    participantsQueryHandler = participantsQueryHandlerSuccess,
  } = {}) => {
    const queryHandlers = [
      [searchUsersQuery, searchQueryHandler],
      [searchUsersQueryOnMR, jest.fn().mockResolvedValue(searchAutocompleteResponseOnMR)],
      [getIssueParticipantsQuery, participantsQueryHandler],
      [getMergeRequestParticipantsQuery, participantsQueryHandler],
    ];
    fakeApollo = createMockApollo(queryHandlers);
    wrapper = shallowMountExtended(UserSelect, {
      apolloProvider: fakeApollo,
      propsData: {
        headerText: 'test',
        text: 'test-text',
        fullPath: '/project',
        iid: '1',
        value: [],
        currentUser: {
          username: 'random',
          name: 'Mr. Random',
        },
        allowMultipleAssignees: false,
        ...props,
      },
      stubs: {
        GlDropdown: {
          template: `
            <div>
              <slot name="header"></slot>
              <slot></slot>
              <slot name="footer"></slot>
            </div>
          `,
        },
        GlSearchBoxByType: stubComponent(GlSearchBoxByType),
      },
    });
  };

  afterEach(() => {
    fakeApollo = null;
  });

  describe('when assignee is disabled', () => {
    describe('and assignee is not selected', () => {
      const createDisabledUserMocks = (users) => ({
        participantsHandler: jest.fn().mockResolvedValue({
          data: {
            namespace: {
              __typename: 'Project',
              id: '1',
              issuable: {
                __typename: 'Issue',
                id: 'gid://gitlab/Issue/1',
                iid: '1',
                participants: {
                  count: users.length,
                  nodes: users,
                },
              },
            },
          },
        }),
        searchHandler: jest.fn().mockResolvedValue({
          data: {
            namespace: {
              __typename: 'Project',
              id: '1',
              users,
            },
          },
        }),
      });

      it('renders disabled assignee', async () => {
        const { participantsHandler, searchHandler } = createDisabledUserMocks([
          mockUser1,
          mockUser2,
          mockDisabledUser,
        ]);

        createComponent({
          participantsQueryHandler: participantsHandler,
          searchQueryHandler: searchHandler,
        });
        await waitForPromises();

        const disabledUser = findUnselectedParticipants()
          .wrappers.find(
            (w) => w.findComponent(SidebarParticipant).props('user')?.username === 'disabled',
          )
          ?.findComponent(SidebarParticipant)
          .props('user');

        expect(disabledUser).toMatchObject({
          username: 'disabled',
          duoStatus: {
            disabled: true,
            disabledReason: 'Out of credits',
          },
        });
      });

      it('shows disabled assignee with disabled status', async () => {
        const { participantsHandler, searchHandler } = createDisabledUserMocks([
          mockDisabledUser,
          mockUser2,
        ]);

        createComponent({
          props: { value: [], currentUser: mockUser1 },
          participantsQueryHandler: participantsHandler,
          searchQueryHandler: searchHandler,
        });
        await waitForPromises();

        const disabledUser = findUnselectedParticipants()
          .wrappers.find(
            (w) => w.findComponent(SidebarParticipant).props('user')?.username === 'disabled',
          )
          ?.findComponent(SidebarParticipant)
          .props('user');

        expect(disabledUser?.duoStatus?.disabled).toBe(true);
      });
    });

    describe('and assignee is already selected', () => {
      beforeEach(async () => {
        createComponent({
          props: {
            value: [mockDisabledUser],
            currentUser: mockUser1,
            iid: null,
          },
          searchQueryHandler: jest.fn().mockResolvedValue({
            data: {
              namespace: {
                users: [mockDisabledUser, mockUser2],
              },
            },
          }),
        });
        await waitForPromises();
      });

      it('allows disabled user to be removed', async () => {
        findSelectedParticipants().at(0).trigger('click');
        await nextTick();

        expect(wrapper.emitted('input')).toEqual([[[]]]);
      });
    });
  });
});
