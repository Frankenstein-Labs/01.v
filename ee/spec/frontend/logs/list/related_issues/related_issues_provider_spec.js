import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RelatedIssuesProvider from 'ee/logs/list/related_issues/related_issues_provider.vue';
import relatedIssuesQuery from 'ee/logs/list/related_issues/graphql/get_logs_related_issues.query.graphql';
import { parseGraphQLIssueLinksToRelatedIssues } from '~/observability/utils';
import { createRelatedIssuesQueryMockResult } from 'jest/observability/mock_data';
import { mockLogs } from '../../mock_data';

jest.mock('~/observability/utils');

Vue.use(VueApollo);

describe('RelatedIssuesProvider component', () => {
  let defaultSlotSpy;
  let relatedIssuesQueryMock;

  const mockLog = mockLogs[0];

  const defaultProps = { projectFullPath: 'foo/bar', log: mockLog };

  let wrapper;

  const mockQueryResult = createRelatedIssuesQueryMockResult('observabilityLogsLinks');

  function createComponent({ props = defaultProps, slots, queryMock } = {}) {
    relatedIssuesQueryMock = queryMock ?? jest.fn().mockResolvedValue(mockQueryResult);
    const apolloProvider = createMockApollo([[relatedIssuesQuery, relatedIssuesQueryMock]]);

    defaultSlotSpy = jest.fn();

    wrapper = shallowMountExtended(RelatedIssuesProvider, {
      apolloProvider,
      propsData: {
        ...props,
      },
      scopedSlots: slots || {
        default: defaultSlotSpy,
      },
    });
  }

  const mockIssues = [
    {
      id: 'mock-issue',
    },
  ];

  beforeEach(() => {
    parseGraphQLIssueLinksToRelatedIssues.mockReturnValue(mockIssues);
  });

  describe('rendered output', () => {
    it('renders correctly with default slot', () => {
      createComponent({ slots: { default: '<div>Test slot content</div>' } });

      expect(wrapper.html()).toContain('Test slot content');
    });

    it('does not render anything without default slot', () => {
      createComponent({ slots: {} });

      expect(wrapper.html()).toBe('');
    });
  });

  describe('graphql query is loading', () => {
    it('calls the default slots with loading = true', () => {
      createComponent();

      expect(defaultSlotSpy).toHaveBeenCalledWith(expect.objectContaining({ loading: true }));
    });
  });

  describe('graphql query loaded', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('calls issues a query for related issues', () => {
      expect(relatedIssuesQueryMock).toHaveBeenCalledWith({
        projectFullPath: defaultProps.projectFullPath,
        traceId: mockLog.trace_id,
        fingerprint: mockLog.fingerprint,
        severityNumber: mockLog.severity_number,
        service: mockLog.service_name,
        timestamp: mockLog.timestamp,
      });
    });

    it('calls the default slots with parsed issue objects', () => {
      expect(defaultSlotSpy).toHaveBeenCalledWith(expect.objectContaining({ issues: mockIssues }));
    });

    it('calls the default slots with loading = false', () => {
      expect(defaultSlotSpy).toHaveBeenCalledWith(expect.objectContaining({ loading: false }));
    });
  });

  describe('error handling', () => {
    it('calls the default slots with error = undefined if query does not fail', async () => {
      createComponent();
      await waitForPromises();

      expect(defaultSlotSpy).toHaveBeenCalledWith(expect.objectContaining({ error: null }));
    });

    it('calls the default slots with error if query fails', async () => {
      createComponent({
        queryMock: jest.fn().mockResolvedValue({ errors: [{ message: 'GraphQL error' }] }),
      });
      await waitForPromises();

      expect(defaultSlotSpy).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(Error) }),
      );
    });
  });
});
