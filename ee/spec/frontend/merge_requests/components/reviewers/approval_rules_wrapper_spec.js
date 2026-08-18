import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { createMockSubscription as createMockApolloSubscription } from 'mock-apollo-client';
import approvalRulesResponse from 'test_fixtures/graphql/merge_requests/approvals/approval_rules.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ApprovalRulesWrapper from 'ee/merge_requests/components/reviewers/approval_rules_wrapper.vue';
import ApprovalRules from 'ee/merge_requests/components/reviewers/approval_rules.vue';
import approvalRulesQuery from 'ee/vue_merge_request_widget/components/approvals/queries/approval_rules.query.graphql';
import mergeRequestApprovalStateUpdated from 'ee/vue_merge_request_widget/components/approvals/queries/approval_rules.subscription.graphql';

Vue.use(VueApollo);

describe('Reviewer drawer approval rules wrapper component', () => {
  let wrapper;
  let mockedSubscription;

  const findApprovalRules = () => wrapper.findAllComponents(ApprovalRules);

  function createComponent() {
    mockedSubscription = createMockApolloSubscription();

    const requestHandlers = [
      [approvalRulesQuery, jest.fn().mockResolvedValue(approvalRulesResponse)],
    ];
    const subscriptionHandlers = [[mergeRequestApprovalStateUpdated, () => mockedSubscription]];
    const apolloProvider = createMockApollo(requestHandlers);

    subscriptionHandlers.forEach(([query, stream]) => {
      apolloProvider.defaultClient.setRequestHandler(query, stream);
    });

    wrapper = shallowMount(ApprovalRulesWrapper, {
      apolloProvider,
      provide: {
        projectPath: 'gitlab-org/gitlab',
        issuableIid: '1',
        issuableId: '1',
        multipleApprovalRulesAvailable: true,
      },
      propsData: {
        reviewers: [],
      },
    });
  }

  it('renders loading skeleton', () => {
    createComponent();

    expect(wrapper.element).toMatchSnapshot();
  });

  it('renders approval rules with rules grouped', async () => {
    createComponent();

    await waitForPromises();

    const rule = findApprovalRules().at(0);

    expect(rule.props('group')).toEqual(
      expect.objectContaining({
        key: 'required',
        sections: expect.arrayContaining([
          expect.objectContaining({
            key: 'regular',
            rules: expect.arrayContaining([
              expect.objectContaining({ type: 'REGULAR', approvalsRequired: 2 }),
            ]),
          }),
        ]),
      }),
    );
  });
});
