import Vue from 'vue';
import VueApollo from 'vue-apollo';
import MergeChecksRebase from '~/vue_merge_request_widget/components/checks/rebase.vue';
import rebaseQuery from 'ee_else_ce/vue_merge_request_widget/queries/states/rebase.query.graphql';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

let wrapper;

const mockPipelineNodes = [
  {
    id: '1',
    project: {
      id: '2',
      fullPath: 'user/forked',
    },
  },
];

const createMockApolloProvider = (handler) => {
  Vue.use(VueApollo);

  return createMockApollo([[rebaseQuery, handler]]);
};

function createWrapper({ handler } = {}) {
  wrapper = mountExtended(MergeChecksRebase, {
    apolloProvider: createMockApolloProvider(handler),
    provide: {},
    propsData: {
      mr: { canPushToSourceBranch: true },
      service: {},
      check: {
        identifier: 'need_rebase',
        status: 'FAILED',
      },
    },
  });
}

describe('Merge request merge checks rebase component', () => {
  describe('rebase message when merge trains are enabled', () => {
    const mockQueryHandlerWithMergeTrains = () =>
      jest.fn().mockResolvedValue({
        data: {
          project: {
            id: '1',
            allowMergeOnSkippedPipeline: true,
            ciCdSettings: {
              mergeTrainsEnabled: true,
            },
            mergeRequest: {
              id: '2',
              rebaseInProgress: false,
              pipelines: {
                nodes: mockPipelineNodes,
              },
            },
          },
        },
      });

    it('displays merge train rebase message when merge trains are enabled', async () => {
      createWrapper({ handler: mockQueryHandlerWithMergeTrains() });

      await waitForPromises();

      expect(wrapper.text()).toContain(
        'Fast forward merge is not possible. Please rebase or use merge train.',
      );
    });
  });
});
