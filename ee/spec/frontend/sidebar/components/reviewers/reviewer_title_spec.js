import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import Component from 'ee/sidebar/components/reviewers/reviewer_title.vue';
import ReviewerDropdown from '~/merge_requests/components/reviewers/reviewer_dropdown.vue';
import getMergeRequestReviewers from '~/sidebar/queries/get_merge_request_reviewers.query.graphql';
import userPermissionsQuery from '~/merge_requests/components/reviewers/queries/user_permissions.query.graphql';

Vue.use(VueApollo);

describe('EE ReviewerTitle component', () => {
  let wrapper;

  const createComponent = (props) => {
    const apolloProvider = createMockApollo([
      [getMergeRequestReviewers, jest.fn().mockResolvedValue({ data: { namespace: null } })],
      [userPermissionsQuery, jest.fn().mockResolvedValue({ data: { project: null } })],
    ]);

    wrapper = shallowMountExtended(Component, {
      apolloProvider,
      propsData: {
        numberOfReviewers: 2,
        editable: true,
        reviewers: [
          { id: 1, username: 'user1' },
          { id: 2, username: 'user2' },
        ],
        ...props,
      },
      provide: {
        projectPath: 'gitlab-org/gitlab',
        issuableId: '1',
        issuableIid: '1',
        multipleApprovalRulesAvailable: false,
        directlyInviteMembers: true,
      },
    });

    return wrapper;
  };

  const findReviewerDropdown = () => wrapper.findComponent(ReviewerDropdown);

  describe('multiple selection enabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes multipleSelectionEnabled prop as true to ReviewerDropdown', () => {
      expect(findReviewerDropdown().props('multipleSelectionEnabled')).toBe(true);
    });
  });

  it('renders 2 reviewers', () => {
    wrapper = createComponent({
      numberOfReviewers: 2,
      editable: false,
    });

    expect(wrapper.vm.$el.innerText.trim()).toEqual('2 Reviewers');
  });
});
