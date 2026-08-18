import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import approvalRulesResponse from 'test_fixtures/graphql/merge_requests/approvals/approvals.query.graphql_approval_rules.json';
import approvalsRequiredResponse from 'test_fixtures/graphql/merge_requests/approvals/approvals.query.graphql_approvals_required.json';
import { toNounSeriesText } from '~/lib/utils/grammar';
import ApprovalsSummary from '~/vue_merge_request_widget/components/approvals/approvals_summary.vue';
import PolicyApprovalSettingsIcon from 'ee/vue_merge_request_widget/components/approvals/policy_approval_settings_icon.vue';

const TEST_APPROVALS_LEFT = 3;

Vue.use(VueApollo);

describe('MRWidget approvals summary', () => {
  let wrapper;

  const defaultProps = {
    canApprove: true,
    disableCommittersApproval: false,
    optional: false,
  };

  const findPolicyApprovalSettingsIcon = () => wrapper.findComponent(PolicyApprovalSettingsIcon);

  const createComponent = (response = approvalRulesResponse, propsData = {}) => {
    wrapper = mount(ApprovalsSummary, {
      propsData: {
        ...defaultProps,
        approvalState: response.data.project.mergeRequest,
        multipleApprovalRulesAvailable: true,
        ...propsData,
      },
    });
  };

  describe('when not approved', () => {
    beforeEach(async () => {
      createComponent();

      await nextTick();
    });

    it('renders message', () => {
      const names = toNounSeriesText(
        approvalRulesResponse.data.project.mergeRequest.approvalState.rules.map((r) => r.name),
      );

      expect(wrapper.text()).toContain(`Requires ${TEST_APPROVALS_LEFT} approvals from ${names}.`);
    });
  });

  describe('when no rulesLeft', () => {
    beforeEach(async () => {
      createComponent(approvalsRequiredResponse);

      await nextTick();
    });

    it('renders message', () => {
      expect(wrapper.text()).toContain(
        `Requires ${TEST_APPROVALS_LEFT} approvals from eligible users`,
      );
    });
  });

  describe('when approval is optional', () => {
    it('renders approval optional text', () => {
      createComponent(approvalRulesResponse, { optional: true });

      expect(wrapper.text()).toContain('Approval is optional');
    });

    it("renders why popover when can't approve", () => {
      window.gon.current_user_id = 1;

      const approvalData = JSON.parse(JSON.stringify(approvalRulesResponse));

      approvalData.data.project.mergeRequest.committers.nodes.push({
        id: 'gid://gitlab/Users/1',
      });

      createComponent(approvalData, { optional: true, disableCommittersApproval: true });

      expect(wrapper.find('[data-testid="commit-cant-approve"]').exists()).toBe(true);
    });
  });

  describe('user committed', () => {
    afterEach(() => {
      window.gon.current_user_id = null;
    });

    it('does not show popover when setting is false', () => {
      createComponent(approvalsRequiredResponse, { disableCommittersApproval: false });

      expect(wrapper.find('[data-testid="commit-cant-approve"]').exists()).toBe(false);
    });

    it('shows popover if current user is a committer', () => {
      const response = JSON.parse(JSON.stringify(approvalsRequiredResponse));
      response.data.project.mergeRequest.committers.nodes.push({ id: 1 });

      window.gon.current_user_id = 1;

      createComponent(response, { disableCommittersApproval: true });

      expect(wrapper.find('[data-testid="commit-cant-approve"]').exists()).toBe(true);
    });
  });

  describe('when policies override approval settings', () => {
    it('renders warning icon', () => {
      const response = JSON.parse(JSON.stringify(approvalsRequiredResponse));
      const policies = [
        {
          name: 'Policy 1',
          editPath: 'edit-policy-1',
          settings: { prevent_approval_by_author: true },
        },
      ];
      response.data.project.mergeRequest.policiesOverridingApprovalSettings = policies;

      createComponent(response);

      expect(findPolicyApprovalSettingsIcon().exists()).toBe(true);
      expect(findPolicyApprovalSettingsIcon().props('policies')).toEqual(policies);
    });
  });
});
