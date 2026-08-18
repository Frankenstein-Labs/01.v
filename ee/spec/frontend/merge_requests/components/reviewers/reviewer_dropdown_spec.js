import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ReviewerDropdown from '~/merge_requests/components/reviewers/reviewer_dropdown.vue';
import userPermissionsQuery from '~/merge_requests/components/reviewers/queries/user_permissions.query.graphql';
import userAutocompleteWithMRPermissionsQuery from 'ee_else_ce/graphql_shared/queries/project_autocomplete_users_with_mr_permissions.query.graphql';

let wrapper;
let autocompleteUsersMock;

Vue.use(VueApollo);

Vue.config.ignoredElements = ['gl-emoji'];

const createMockUser = ({
  id = 1,
  name = 'Administrator',
  username = 'root',
  mergeRequestInteraction = {},
} = {}) => ({
  __typename: 'UserCore',
  id: `gid://gitlab/User/${id}`,
  avatarUrl:
    'https://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80\u0026d=identicon',
  webUrl: `/${username}`,
  webPath: `/${username}`,
  status: null,
  mergeRequestInteraction: {
    canMerge: true,
    ...mergeRequestInteraction,
  },
  username,
  name,
});

function createComponent({ adminMergeRequest = true, customUsers = [] }) {
  autocompleteUsersMock = jest.fn().mockResolvedValue({
    data: {
      namespace: {
        id: 1,
        users: customUsers,
      },
    },
  });

  const apolloProvider = createMockApollo(
    [
      [userAutocompleteWithMRPermissionsQuery, autocompleteUsersMock],
      [
        userPermissionsQuery,
        jest.fn().mockResolvedValue({
          data: {
            project: {
              id: 1,
              mergeRequest: { id: 1, userPermissions: { adminMergeRequest, canMerge: true } },
            },
          },
        }),
      ],
    ],
    {},
    {
      typePolicies: { Query: { fields: { project: { merge: true } } } },
    },
  );

  wrapper = mountExtended(ReviewerDropdown, {
    apolloProvider,
    propsData: {
      users: customUsers,
    },
    provide: {
      projectPath: 'gitlab-org/gitlab',
      issuableId: '1',
      issuableIid: '1',
      directlyInviteMembers: true,
    },
    stubs: {
      'gl-emoji': true,
    },
  });
}

const findApprovalRule = () => wrapper.findByTestId('approval-rule');
const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

const mockUser = createMockUser({
  mergeRequestInteraction: {
    applicableApprovalRules: [{ id: 1, name: 'Frontend', type: 'CODE_OWNER' }],
  },
});

describe('Reviewer dropdown component', () => {
  it('renders dropdown approval rule', async () => {
    createComponent({ adminMergeRequest: true, customUsers: [mockUser] });

    await waitForPromises();

    findDropdown().vm.$emit('shown');

    expect(findApprovalRule().text()).toContain('Code Owner');
  });
});
