import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import AiGenie from 'ee_component/ai/components/ai_genie.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BlobContentViewer from '~/repository/components/blob_content_viewer.vue';
import blobInfoQuery from 'shared_queries/repository/blob_info.query.graphql';
import projectInfoQuery from 'ee/repository/queries/project_info.query.graphql';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  getProjectMockWithOverrides,
  projectMock,
  userPermissionsMock,
  simpleViewerMock,
  richViewerMock,
  propsMock,
  FILE_SIZE_3MB,
} from 'ee_jest/repository/mock_data';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';

jest.mock('~/lib/utils/common_utils');
Vue.use(VueRouter);
const router = new VueRouter({ mode: 'history' });
const mockAxios = new MockAdapter(axios);

let wrapper;
let mockResolver;

Vue.use(Vuex);
Vue.use(VueApollo);

const explainCodeSubscriptionResponse = {
  data: {
    aiCompletionResponse: {
      id: '1',
      requestId: '2',
      content: 'test',
      contentHtml: '',
      role: '',
      timestamp: '',
      type: '',
      chunkId: '',
      errors: [],
      extras: { sources: '' },
    },
  },
};
const subscriptionHandlerMock = jest.fn().mockResolvedValue(explainCodeSubscriptionResponse);

const createMockStore = () =>
  new Vuex.Store({ actions: { fetchData: jest.fn, setInitialData: jest.fn() } });

const createComponent = async (mockData = {}) => {
  const {
    blob = simpleViewerMock,
    empty = projectMock.repository.empty,
    pushCode = userPermissionsMock.pushCode,
    forkProject = userPermissionsMock.forkProject,
    downloadCode = userPermissionsMock.downloadCode,
    createMergeRequestIn = userPermissionsMock.createMergeRequestIn,
    isBinary,
    path = propsMock.projectPath,
    explainCodeAvailable = true,
    activeViewerType = 'simple',
  } = mockData;

  blob.fileType = 'podspec';

  const project = {
    ...getProjectMockWithOverrides({
      userPermissionsOverride: {
        pushCode,
        forkProject,
        downloadCode,
        createMergeRequestIn,
      },
    }),
    repository: {
      __typename: 'Repository',
      empty,
      blobs: { __typename: 'RepositoryBlobConnection', nodes: [blob] },
    },
  };

  mockResolver = jest.fn().mockResolvedValue({
    data: { isBinary, project },
  });

  const fakeApollo = createMockApollo([
    [blobInfoQuery, mockResolver],
    [projectInfoQuery, mockResolver],
    [aiResponseSubscription, subscriptionHandlerMock],
  ]);

  wrapper = mountExtended(BlobContentViewer, {
    store: createMockStore(),
    router,
    apolloProvider: fakeApollo,
    propsData: {
      ...propsMock,
      path,
    },
    provide: {
      targetBranch: 'test',
      originalBranch: 'test',
      resourceId: 'test',
      userId: 'test',
      explainCodeAvailable,
      highlightWorker: { postMessage: jest.fn() },
      activeViewerType,
    },
  });

  await waitForPromises();
};

const findAiGenie = () => wrapper.findComponent(AiGenie);

describe('Blob content viewer component', () => {
  beforeEach(() => {
    isLoggedIn.mockReturnValue(true);
  });

  afterEach(() => {
    mockAxios.reset();
  });

  describe('AI Genie component', () => {
    it.each`
      prefix        | explainCodeAvailable | shouldRender | blob
      ${'does not'} | ${false}             | ${false}     | ${simpleViewerMock}
      ${'does'}     | ${true}              | ${true}      | ${simpleViewerMock}
      ${'does not'} | ${false}             | ${false}     | ${richViewerMock}
      ${'does not'} | ${true}              | ${false}     | ${richViewerMock}
      ${'does not'} | ${true}              | ${false}     | ${{ ...simpleViewerMock, size: FILE_SIZE_3MB, simpleViewer: { ...simpleViewerMock.simpleViewer } }}
    `(
      '$prefix render the AI Genie component when explainCodeAvailable flag is $explainCodeAvailable and correct blob is rendered',
      async ({ explainCodeAvailable, blob, shouldRender }) => {
        await createComponent({ explainCodeAvailable, blob });
        expect(findAiGenie().exists()).toBe(shouldRender);
      },
    );

    it('sets correct props on the AI Genie component', async () => {
      await createComponent();
      expect(findAiGenie().props('containerSelector')).toBe('.file-content');
      expect(findAiGenie().props('filePath')).toBe(propsMock.projectPath);
    });
  });
});
