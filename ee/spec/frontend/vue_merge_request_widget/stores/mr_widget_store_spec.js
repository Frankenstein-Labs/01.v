import getStateQueryResponse from 'test_fixtures/graphql/merge_requests/get_state.query.graphql.json';
import MergeRequestStore from 'ee/vue_merge_request_widget/stores/mr_widget_store';
import mockData from 'ee_jest/vue_merge_request_widget/mock_data';

import { convertToCamelCase } from '~/lib/utils/text_utility';
import { stateKey } from '~/vue_merge_request_widget/stores/state_maps';
import { MWCP_MERGE_STRATEGY, DETAILED_MERGE_STATUS } from '~/vue_merge_request_widget/constants';

describe('MergeRequestStore', () => {
  let store;

  beforeEach(() => {
    store = new MergeRequestStore(mockData);
  });

  describe('isNothingToMergeState', () => {
    it('returns true when nothingToMerge', () => {
      store.state = stateKey.nothingToMerge;

      expect(store.isNothingToMergeState).toEqual(true);
    });

    it('returns false when not nothingToMerge', () => {
      store.state = 'state';

      expect(store.isNothingToMergeState).toEqual(false);
    });
  });

  describe('setData', () => {
    describe('mergePipelinesEnabled', () => {
      it('should set mergePipelinesEnabled = true when merge_pipelines_enabled is true', () => {
        store.setData({ ...mockData, merge_pipelines_enabled: true });

        expect(store.mergePipelinesEnabled).toBe(true);
      });

      it('should set mergePipelinesEnabled = false when merge_pipelines_enabled is not provided', () => {
        store.setData({ ...mockData, merge_pipelines_enabled: undefined });

        expect(store.mergePipelinesEnabled).toBe(false);
      });
    });
  });

  describe('setGraphqlData', () => {
    const { mergeRequest } = getStateQueryResponse.data.project;

    it('sets mergeTrainsCount', () => {
      store.setGraphqlData({
        mergeTrains: {
          nodes: [
            {
              cars: {
                count: 2,
              },
            },
          ],
        },
        mergeRequest: {
          ...mergeRequest,
        },
      });

      expect(store.mergeTrainsCount).toBe(2);
    });
  });

  describe('setGraphqlSubscriptionData', () => {
    it('sets mergeTrainsCount', () => {
      store.setGraphqlSubscriptionData({
        mergeRequest: {
          project: {
            mergeTrains: {
              nodes: [
                {
                  cars: {
                    count: 2,
                  },
                },
              ],
            },
          },
        },
        mergeTrainsCount: 2,
      });

      expect(store.mergeTrainsCount).toBe(2);
    });
  });

  describe('setPaths', () => {
    it.each(['discover_project_security_path', 'saml_approval_path'])(
      'should set %s path',
      (property) => {
        // Ensure something is set in the mock data
        expect(property in mockData).toBe(true);
        const expectedValue = mockData[property];

        store.setPaths({ ...mockData });

        expect(store[convertToCamelCase(property)]).toBe(expectedValue);
      },
    );
  });

  describe('preventMerge', () => {
    beforeEach(() => {
      store.hasApprovalsAvailable = true;
    });

    it('is false when MR is approved', () => {
      store.setApprovals({ approved: true });

      expect(store.preventMerge).toBe(false);
    });

    it('is true when MR is not approved', () => {
      store.setApprovals({ approved: false });

      expect(store.preventMerge).toBe(true);
    });

    it('is false when MR is not approved and preferredAutoMergeStrategy is MWCP', () => {
      store.setData({ ...mockData, available_auto_merge_strategies: [MWCP_MERGE_STRATEGY] });

      store.setApprovals({ approved: false });

      expect(store.preventMerge).toBe(false);
    });
  });

  describe('hasMergeChecksFailed', () => {
    it('should be true when detailed merge status is EXTERNAL_STATUS_CHECKS', () => {
      store.detailedMergeStatus = DETAILED_MERGE_STATUS.EXTERNAL_STATUS_CHECKS;

      expect(store.hasMergeChecksFailed).toBe(true);
    });

    it('should be false when preferredAutoMergeStrategy is MWCP and MR is not approved', () => {
      store.hasApprovalsAvailable = true;
      store.detailedMergeStatus = DETAILED_MERGE_STATUS.NOT_APPROVED;

      store.setData({ ...mockData, available_auto_merge_strategies: [MWCP_MERGE_STRATEGY] });

      store.setApprovals({ isApproved: false, approvalsLeft: 1 });

      expect(store.hasMergeChecksFailed).toBe(false);
    });
  });
});
