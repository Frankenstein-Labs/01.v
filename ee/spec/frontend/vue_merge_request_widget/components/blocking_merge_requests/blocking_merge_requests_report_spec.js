import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';
import { shallowMount, config } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlockingMergeRequestsReport from 'ee/vue_merge_request_widget/components/blocking_merge_requests/blocking_merge_requests_report.vue';
import ReportSection from '~/ci/reports/components/report_section.vue';
import { status as reportStatus } from '~/ci/reports/constants';
import blockingMergeRequestsQuery from 'ee/vue_merge_request_widget/queries/blocking_merge_requests.query.graphql';

Vue.use(VueApollo);

function createMergeRequest(override = {}) {
  return {
    id: 1,
    iid: 1,
    reference: '!1',
    milestone: {
      id: 1,
      title: 'Milestone title',
      dueDate: null,
      startDate: null,
    },
    assignees: {
      nodes: [
        {
          id: 1,
          name: 'root',
          username: 'root',
          webUrl: 'https://gitlab.com',
          avatarUrl: 'https://gitlab.com',
        },
      ],
    },
    headPipeline: null,
    createdAt: null,
    mergedAt: null,
    webUrl: 'https://gitlab.com',
    state: 'opened',
    title: 'Merge request title',
    ...override,
  };
}

describe('BlockingMergeRequestsReport', () => {
  let wrapper;
  let blockingMergeRequests;

  // Remove these hooks once we update @vue/test-utils
  // See this issue: https://github.com/vuejs/vue-test-utils/issues/973
  beforeAll(() => {
    config.logModifiedComponents = false;
  });

  afterAll(() => {
    config.logModifiedComponents = true;
  });

  beforeEach(() => {
    blockingMergeRequests = {
      totalCount: 3,
      hiddenCount: 0,
      visibleMergeRequests: [
        createMergeRequest(),
        createMergeRequest({ id: 2, iid: 2, state: 'closed' }),
        createMergeRequest({ id: 3, iid: 3, state: 'merged' }),
      ],
    };
  });

  const createComponent = () => {
    const apolloProvider = createMockApollo([
      [
        blockingMergeRequestsQuery,
        jest.fn().mockResolvedValue({
          data: { project: { id: 1, mergeRequest: { id: 1, blockingMergeRequests } } },
        }),
      ],
    ]);

    wrapper = shallowMount(BlockingMergeRequestsReport, {
      propsData: {
        mr: {},
      },
      apolloProvider,
      stubs: {
        ReportSection,
      },
    });
  };

  it('does not render blocking merge requests report if no blocking MRs exist', async () => {
    blockingMergeRequests.totalCount = 0;
    blockingMergeRequests.visibleMergeRequests = [];
    createComponent();

    await waitForPromises();

    expect(wrapper.find('*').exists()).toBe(false);
  });

  it('passes merged MRs as resolved issues and anything else as unresolved', async () => {
    createComponent();

    await waitForPromises();

    const reportSectionProps = wrapper.findComponent(ReportSection).props();

    expect(reportSectionProps.resolvedIssues).toHaveLength(1);
    expect(reportSectionProps.resolvedIssues[0].id).toBe(3);
  });

  it('passes all non "merged" MRs as unresolved issues', async () => {
    createComponent();

    await waitForPromises();
    const reportSectionProps = wrapper.findComponent(ReportSection).props();

    expect(reportSectionProps.unresolvedIssues.map((issue) => issue.id)).toEqual([2, 1]);
  });

  it('sets status to "ERROR" when there are unmerged blocking MRs', async () => {
    createComponent();

    await waitForPromises();

    expect(wrapper.findComponent(ReportSection).props().status).toBe(reportStatus.ERROR);
  });

  it('sets status to "SUCCESS" when all blocking MRs are merged', async () => {
    blockingMergeRequests.totalCount = 1;
    blockingMergeRequests.visibleMergeRequests = [createMergeRequest({ state: 'merged' })];
    createComponent();

    await waitForPromises();

    expect(wrapper.findComponent(ReportSection).props().status).toBe(reportStatus.SUCCESS);
  });

  describe('blockedByText', () => {
    it('contains closed information if some are closed, but not all', async () => {
      createComponent();

      await waitForPromises();

      expect(wrapper.findComponent(GlSprintf).attributes('message')).toContain(
        'Depends on 2 merge requests being merged',
      );
      expect(wrapper.findComponent(GlSprintf).attributes('message')).toContain('(1 closed)');
    });

    it('does not contain closed information if no blocking MRs are closed', async () => {
      blockingMergeRequests.visibleMergeRequests = [createMergeRequest({ state: 'opened' })];
      createComponent();

      await waitForPromises();

      expect(wrapper.findComponent(GlSprintf).attributes('message')).not.toContain('closed');
    });

    it('states when all blocking mrs are closed', async () => {
      blockingMergeRequests.visibleMergeRequests = [createMergeRequest({ state: 'closed' })];
      createComponent();

      await waitForPromises();

      expect(wrapper.findComponent(GlSprintf).attributes('message')).toContain(
        'Depends on %{strongStart}1 closed%{strongEnd} merge request.',
      );
    });

    it('when all blocking mrs are merged', async () => {
      blockingMergeRequests.visibleMergeRequests = [createMergeRequest({ state: 'merged' })];
      createComponent();

      await waitForPromises();

      expect(wrapper.text()).toContain('All merge request dependencies have been merged');
      expect(wrapper.text()).toContain('(3 merged)');
    });
  });

  describe('unmergedBlockingMergeRequests', () => {
    it('does not include merged MRs', async () => {
      createComponent();

      await waitForPromises();

      const containsMergedMRs = wrapper.vm.unmergedBlockingMergeRequests.some(
        (mr) => mr.state === 'merged',
      );

      expect(containsMergedMRs).toBe(false);
    });

    it('puts closed MRs first', async () => {
      createComponent();

      await waitForPromises();

      const closedIndex = wrapper.vm.unmergedBlockingMergeRequests.findIndex(
        (mr) => mr.state === 'closed',
      );

      expect(closedIndex).toBe(0);
    });
  });
});
