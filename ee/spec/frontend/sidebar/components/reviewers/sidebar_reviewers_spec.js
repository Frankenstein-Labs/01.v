import Vue from 'vue';
import AxiosMockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import { createMockSubscription as createMockApolloSubscription } from 'mock-apollo-client';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import axios from '~/lib/utils/axios_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import stubChildren from 'helpers/stub_children';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import getMergeRequestReviewersQuery from '~/sidebar/queries/get_merge_request_reviewers.query.graphql';
import mergeRequestReviewersUpdatedSubscription from '~/sidebar/queries/merge_request_reviewers.subscription.graphql';
import SidebarReviewers from '~/sidebar/components/reviewers/sidebar_reviewers.vue';
import SidebarMediator from '~/sidebar/sidebar_mediator';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';
import { useBatchComments } from '~/batch_comments/store';
import { mockGetMergeRequestReviewers } from '../../mock_data';

const { bindInternalEventDocument } = useMockInternalEventsTracking();

Vue.use(VueApollo);
Vue.use(PiniaVuePlugin);

describe('sidebar reviewers', () => {
  const mockGQLQueries = [
    [getMergeRequestReviewersQuery, jest.fn().mockResolvedValue(mockGetMergeRequestReviewers)],
  ];

  const mockedSubscription = createMockApolloSubscription();
  const apolloMock = createMockApollo(mockGQLQueries);
  let trackEventSpy;
  let wrapper;
  let mediator;
  let axiosMock;
  let pinia;

  apolloMock.defaultClient.setRequestHandler(
    mergeRequestReviewersUpdatedSubscription,
    () => mockedSubscription,
  );

  const findAssignButton = () => wrapper.findByTestId('sidebar-reviewers-assign-button');

  const createComponent = ({ props = {} } = {}) => {
    wrapper = mountExtended(SidebarReviewers, {
      apolloProvider: apolloMock,
      pinia,
      propsData: {
        issuableIid: '1',
        issuableId: 1,
        mediator,
        field: '',
        projectPath: 'projectPath',
        changing: false,
        ...props,
      },
      provide: {
        projectPath: 'projectPath',
        issuableId: 1,
        issuableIid: 1,
        multipleApprovalRulesAvailable: false,
      },
      stubs: {
        ...stubChildren(SidebarReviewers),
        GlButton: false,
      },
      // Attaching to document is required because this component emits something from the parent element :/
      attachTo: document.body,
    });

    ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
  };

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });
    useLegacyDiffs();
    useNotes();
    useBatchComments();
    axiosMock = new AxiosMockAdapter(axios);
    mediator = new SidebarMediator({ currentUser: {} });
  });

  afterEach(() => {
    axiosMock.restore();
  });

  it('sends the telemetry event when the reviewers panel is opened', async () => {
    createComponent();
    await waitForPromises();

    const assign = findAssignButton();

    assign.trigger('click');

    expect(trackEventSpy).toHaveBeenCalledWith('open_reviewer_sidebar_panel_in_mr', {}, undefined);
  });
});
