import {
  GlModal,
  GlDisclosureDropdown,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CommentTemplatesDropdown from '~/vue_shared/components/markdown/comment_templates_modal.vue';
import savedRepliesQuery from 'ee/vue_shared/components/markdown/saved_replies.query.graphql';

let wrapper;
let savedRepliesResp;

function createResponse() {
  return {
    data: {
      group: {
        id: 'gid://gitlab/Group/2',
        savedReplies: {
          nodes: [
            {
              id: 'gid://gitlab/Groups::SavedReply/1',
              name: 'group saved reply',
              content: 'Group saved reply content',
              __typename: 'GroupsSavedReply',
            },
          ],
        },
        __typename: 'Group',
      },
      project: {
        id: 'gid://gitlab/Project/2',
        savedReplies: {
          nodes: [
            {
              id: 'gid://gitlab/Projects::SavedReply/1',
              name: 'project saved reply',
              content: 'Project saved reply content',
              __typename: 'ProjectsSavedReply',
            },
          ],
        },
        __typename: 'Project',
      },
      currentUser: {
        id: 'gid://gitlab/User/2',
        savedReplies: {
          nodes: [
            {
              id: 'gid://gitlab/Users::SavedReply/1',
              name: 'saved_reply_1',
              content: 'Saved Reply Content',
              __typename: 'SavedReply',
            },
          ],
        },
        __typename: 'CurrentUser',
      },
    },
  };
}

function createMockApolloProvider(response = createResponse()) {
  Vue.use(VueApollo);

  savedRepliesResp = jest.fn().mockResolvedValue(response);

  const requestHandlers = [[savedRepliesQuery, savedRepliesResp]];

  return createMockApollo(requestHandlers);
}

function createComponent(options = {}) {
  const { mockApollo } = options;

  document.body.dataset.groupFullPath = 'gitlab-org';

  return shallowMountExtended(CommentTemplatesDropdown, {
    propsData: {
      newCommentTemplatePaths: [{ path: '/new', text: 'New' }],
    },
    apolloProvider: mockApollo,
    stubs: {
      GlModal,
      GlDisclosureDropdown,
      GlDisclosureDropdownGroup,
      GlDisclosureDropdownItem,
    },
  });
}

const findGroups = () =>
  wrapper.findByTestId('comment-templates-list').findAllComponents(GlDisclosureDropdownGroup);

describe('EE comment templates dropdown', () => {
  afterEach(() => {
    delete document.body.dataset.groupFullPath;
    delete document.body.dataset.projectFullPath;
  });

  it('renders group and user comment templates', async () => {
    const mockApollo = createMockApolloProvider();
    wrapper = createComponent({ mockApollo });

    wrapper.findComponent('.js-comment-template-toggle').vm.$emit('click');

    await waitForPromises();

    const groups = findGroups();

    expect(groups).toHaveLength(2);
    expect(groups.at(0).text()).toContain('User');
    expect(groups.at(0).text()).toContain('saved_reply_1');
    expect(groups.at(1).text()).toContain('Group');
    expect(groups.at(1).text()).toContain('group saved reply');
  });

  it('renders project, group and user comment templates', async () => {
    document.body.dataset.projectFullPath = 'gitlab-org';

    const mockApollo = createMockApolloProvider();
    wrapper = createComponent({ mockApollo });

    wrapper.findComponent('.js-comment-template-toggle').vm.$emit('click');

    await waitForPromises();

    const groups = findGroups();

    expect(groups).toHaveLength(3);
    expect(groups.at(0).text()).toContain('saved_reply_1');
    expect(groups.at(0).text()).toContain('User');
    expect(groups.at(1).text()).toContain('project saved reply');
    expect(groups.at(1).text()).toContain('Project');
    expect(groups.at(2).text()).toContain('group saved reply');
    expect(groups.at(2).text()).toContain('Group');
  });
});
