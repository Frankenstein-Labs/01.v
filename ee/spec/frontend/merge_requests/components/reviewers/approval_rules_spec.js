import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ApprovalRules from 'ee/merge_requests/components/reviewers/approval_rules.vue';
import userPermissionsQuery from '~/merge_requests/components/reviewers/queries/user_permissions.query.graphql';

Vue.use(VueApollo);

describe('Reviewer drawer approval rules component', () => {
  let wrapper;

  const findOptionalToggle = () => wrapper.findComponentByTestId('optional-rules-toggle');
  const findRuleRows = () => wrapper.findAll('tbody tr');
  const findReviewerDropdown = () => wrapper.findComponentByTestId('reviewer-dropdown');

  function createComponent({
    rule = null,
    approvalsRequired = 1,
    key = 'required',
    reviewers = [],
    fn = mountExtended,
  } = {}) {
    const apolloProvider = createMockApollo([
      [userPermissionsQuery, jest.fn().mockResolvedValue({ data: { project: null } })],
    ]);

    wrapper = fn(ApprovalRules, {
      apolloProvider,
      provide: {
        projectPath: 'gitlab-org/gitlab',
        issuableId: 1,
        issuableIid: 1,
        directlyInviteMembers: false,
      },
      propsData: {
        reviewers,
        group: {
          label: 'Rule',
          key,
          sections: [
            {
              label: 'Approval rules',
              key: 'rules',
              rules: [
                {
                  approvalsRequired,
                  name: 'Optional rule',
                  type: 'any_approver',
                  approvedBy: {
                    nodes: [],
                  },
                },
                {
                  approvalsRequired,
                  name: 'Required rule',
                  type: 'code_owner',
                  approvedBy: {
                    nodes: [],
                  },
                },
                {
                  approvalsRequired,
                  name: 'Approved rule',
                  type: 'regular',
                  approvedBy: {
                    nodes: [{ id: 1 }],
                  },
                },
                rule,
              ].filter((r) => r),
            },
          ],
        },
      },
    });
  }

  it('renders optional rules toggle button', () => {
    createComponent({ key: 'optional' });

    expect(findOptionalToggle().exists()).toBe(true);
    expect(findOptionalToggle().text()).toBe('Optional approvals');
  });

  it('renders non-optional rules by default', () => {
    createComponent();

    const row = findRuleRows().at(0);

    expect(row.element).toMatchSnapshot();
  });

  it('renders approved by count', () => {
    createComponent();

    const row = findRuleRows().at(2);

    expect(row.text()).toContain('1 of 1');
  });

  it('toggles optional rows when clicking toggle', async () => {
    createComponent({ key: 'optional' });

    expect(findRuleRows()).toHaveLength(0);

    findOptionalToggle().vm.$emit('click');

    await nextTick();

    expect(findRuleRows()).toHaveLength(3);
  });

  it('sets the reviewer dropdown to allow multiple selection', () => {
    createComponent({ key: 'rules', fn: shallowMountExtended });

    expect(findReviewerDropdown().props('multipleSelectionEnabled')).toBe(true);
  });

  describe('when codeowners rule exists', () => {
    it('renders section name', () => {
      createComponent({
        rule: {
          approvalsRequired: 1,
          name: 'Approved rule',
          section: 'Frontend',
          type: 'code_owner',
          approvedBy: {
            nodes: [{ id: 1 }],
          },
        },
      });

      expect(wrapper.findByTestId('section-name').text()).toBe('Frontend');
    });

    it('does not render section name when codeowners rule does not have a section name', () => {
      createComponent({
        rule: {
          approvalsRequired: 1,
          name: 'Approved rule',
          section: 'codeowners',
          type: 'code_owner',
          approvedBy: {
            nodes: [{ id: 1 }],
          },
        },
      });

      expect(wrapper.findByTestId('section-name').exists()).toBe(false);
    });
  });

  describe('when rule is any approver', () => {
    it('shows reviewers who are not attached to a approval rule', () => {
      createComponent({
        rule: {
          id: '1',
          approvalsRequired: 1,
          name: 'Any approval rule',
          section: 'optional',
          type: 'any_approver',
          approvedBy: { nodes: [] },
        },
        reviewers: [
          {
            id: 1,
            username: 'root',
            mergeRequestInteraction: { applicableApprovalRules: [] },
          },
          {
            id: 2,
            username: 'user',
            mergeRequestInteraction: { applicableApprovalRules: [{ id: 10 }] },
          },
        ],
      });

      const reviewers = wrapper.findComponentByTestId('approval-rule-reviewers');

      expect(reviewers.exists()).toBe(true);
      expect(reviewers.props('users')).toContainEqual(
        expect.objectContaining({
          id: 1,
          username: 'root',
        }),
      );
    });
  });
});
