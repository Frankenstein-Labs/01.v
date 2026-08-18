import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlSprintf } from '@gitlab/ui';
import MRWidgetAutoMergeEnabled from '~/vue_merge_request_widget/components/states/mr_widget_auto_merge_enabled.vue';
import {
  MWCP_MERGE_STRATEGY,
  MT_MERGE_STRATEGY,
  MTWCP_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import autoMergeEnabledQuery from 'ee/vue_merge_request_widget/queries/states/auto_merge_enabled.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import StateContainer from '~/vue_merge_request_widget/components/state_container.vue';
import MrWidgetAuthor from '~/vue_merge_request_widget/components/mr_widget_author.vue';

function convertPropsToGraphqlState(props) {
  return {
    id: '1',
    autoMergeStrategy: props.autoMergeStrategy,
    cancelAutoMergePath: 'http://text.com',
    mergeUser: {
      id: props.mergeUserId,
      name: '',
      username: '',
      webUrl: '',
      avatarUrl: '',
      ...props.setToAutoMergeBy,
    },
    targetBranch: props.targetBranch,
    targetBranchCommitsPath: props.targetBranchPath,
    shouldRemoveSourceBranch: props.shouldRemoveSourceBranch,
    forceRemoveSourceBranch: props.shouldRemoveSourceBranch,
    userPermissions: {
      removeSourceBranch: props.canRemoveSourceBranch,
    },
    __typename: 'MergeRequest',
  };
}

const mr = {
  shouldRemoveSourceBranch: false,
  canRemoveSourceBranch: true,
  canCancelAutomaticMerge: true,
  mergeUserId: 1,
  currentUserId: 1,
  setToAutoMergeBy: {},
  sha: '1EA2EZ34',
  targetBranchPath: '/foo/bar',
  targetBranch: 'foo',
  autoMergeStrategy: MTWCP_MERGE_STRATEGY,
};

const generateMockResponse = ({ mergeRequest, mergeTrainsCount } = {}) => ({
  data: {
    project: {
      id: '1',
      mergeRequest: convertPropsToGraphqlState({ ...mr, ...mergeRequest }),
      mergeTrains: {
        nodes: [
          {
            cars: {
              count: mergeTrainsCount,
            },
          },
        ],
        __typename: 'MergeTrainConnection',
      },
      __typename: 'Project',
    },
  },
});

Vue.use(VueApollo);

describe('MRWidgetAutoMergeEnabled', () => {
  let wrapper;
  let service;

  const getStatusText = () => wrapper.find('[data-testid="statusText"]').text();

  const createComponent = ({ mergeRequest, mergeTrainsCount = 0 } = {}) => {
    const mockResponse = jest
      .fn()
      .mockResolvedValue(generateMockResponse({ mergeRequest, mergeTrainsCount }));
    const apolloProvider = createMockApollo([[autoMergeEnabledQuery, mockResponse]]);

    wrapper = shallowMount(MRWidgetAutoMergeEnabled, {
      apolloProvider,
      propsData: {
        mr,
        service,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    service = {
      merge: jest.fn(),
      poll: jest.fn(),
    };
    window.gl = {
      mrWidgetData: {
        defaultAvatarUrl: 'no_avatar.png',
      },
    };
  });

  describe('status', () => {
    it('should return "to be merged automatically..." if MWCP is selected', async () => {
      createComponent({
        mergeRequest: {
          autoMergeStrategy: MWCP_MERGE_STRATEGY,
        },
        mergeTrainsCount: 1,
      });

      await waitForPromises();

      expect(getStatusText()).toContain('to be merged automatically when all merge checks pass');
    });

    it('should return "to be added to the merge train..." if MTWCP is selected', async () => {
      createComponent({
        mergeRequest: {
          autoMergeStrategy: MTWCP_MERGE_STRATEGY,
        },
        mergeTrainsCount: 1,
      });

      await waitForPromises();

      expect(getStatusText()).toContain(
        'to be added to the merge train when all merge checks pass',
      );
    });

    it('should return "start a merge train..." if MTWCP is selected', async () => {
      createComponent({
        mergeRequest: {
          autoMergeStrategy: MTWCP_MERGE_STRATEGY,
        },
      });

      await waitForPromises();

      expect(getStatusText()).toContain('to start a merge train when all merge checks pass');
    });
  });

  describe('cancelButtonText', () => {
    it('should return "Remove from merge train" if the pipeline has been added to the merge train', async () => {
      createComponent({
        mergeRequest: {
          autoMergeStrategy: MT_MERGE_STRATEGY,
        },
        mergeTrainsCount: 0,
      });

      await waitForPromises();

      expect(wrapper.findComponent(StateContainer).props('actions')).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            text: 'Remove from merge train',
            testId: 'cancelAutomaticMergeButton',
          }),
        ]),
      );
    });
  });

  it('should refetch state on subsequent mounts', async () => {
    const resolver = jest.fn().mockResolvedValueOnce(
      generateMockResponse({
        mergeRequest: { setToAutoMergeBy: { name: 'Foo' } },
        mergeTrainsCount: 1,
      }),
    );
    const apolloProvider = createMockApollo([[autoMergeEnabledQuery, resolver]]);
    const mountComponent = () => {
      wrapper = shallowMount(MRWidgetAutoMergeEnabled, {
        apolloProvider,
        propsData: {
          mr,
          service,
        },
        stubs: {
          GlSprintf,
        },
      });
    };

    mountComponent();
    await waitForPromises();
    wrapper.destroy();
    resolver.mockResolvedValueOnce(
      generateMockResponse({
        mergeRequest: { setToAutoMergeBy: { name: 'Bar' } },
        mergeTrainsCount: 1,
      }),
    );

    mountComponent();
    await waitForPromises();

    expect(wrapper.findComponent(MrWidgetAuthor).props('author').name).toBe('Bar');
  });
});
