import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import OpenTimeboxSummary from 'ee/burndown_chart/components/open_timebox_summary.vue';
import summaryStatsQuery from 'ee/burndown_chart/graphql/iteration_issues_summary.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('Iterations report summary', () => {
  let slotSpy;

  const id = 3;
  const defaultProps = {
    fullPath: 'gitlab-org',
    iterationId: `gid://gitlab/Iteration/${id}`,
  };

  const summaryStatsResponse = {
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        openIssues: { count: 5, __typename: 'IssueConnection' },
        assignedIssues: { count: 3, __typename: 'IssueConnection' },
        closedIssues: { count: 10, __typename: 'IssueConnection' },
        __typename: 'Group',
      },
    },
  };

  const mountComponent = ({
    props = defaultProps,
    queryHandler = jest.fn().mockResolvedValue(summaryStatsResponse),
  } = {}) => {
    slotSpy = jest.fn();

    shallowMount(OpenTimeboxSummary, {
      apolloProvider: createMockApollo([[summaryStatsQuery, queryHandler]]),
      propsData: props,
      scopedSlots: {
        default: slotSpy,
      },
    });
  };

  describe('with valid totals', () => {
    beforeEach(async () => {
      mountComponent();

      await waitForPromises();
    });

    it('passes data to cards component', () => {
      expect(slotSpy).toHaveBeenCalledWith({
        loading: false,
        columns: [
          {
            title: 'Completed',
            value: 10,
          },
          {
            title: 'Incomplete',
            value: 3,
          },
          {
            title: 'Unstarted',
            value: 5,
          },
        ],
        total: 18,
      });
    });
  });
});
