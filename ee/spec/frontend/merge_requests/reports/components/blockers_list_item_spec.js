import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ReportListItem from '~/merge_requests/reports/components/report_list_item.vue';
import BlockersListItem from 'ee/merge_requests/reports/components/blockers_list_item.vue';
import violationsCountQuery from 'ee/merge_requests/reports/queries/violations_count.query.graphql';

Vue.use(VueApollo);

describe('Merge request reports blockers list item component', () => {
  let wrapper;

  const findReportListItem = () => wrapper.findComponent(ReportListItem);

  const createComponent = (violationsCount = null) => {
    const apolloProvider = createMockApollo([
      [
        violationsCountQuery,
        jest.fn().mockResolvedValue({
          data: {
            project: { id: 1, mergeRequest: { id: 1, policyViolations: { violationsCount } } },
          },
        }),
      ],
    ]);
    wrapper = shallowMountExtended(BlockersListItem, {
      apolloProvider,
      provide: { projectPath: 'gitlab-org/gitlab', iid: '2' },
    });
  };

  it.each`
    violationsCount | status
    ${0}            | ${'success'}
    ${1}            | ${'failed'}
  `('sets status as $status for count $violationsCount', async ({ violationsCount, status }) => {
    createComponent(violationsCount);

    await waitForPromises();

    expect(findReportListItem().props('statusIcon')).toBe(status);
  });
});
