import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { CONTENT_EDITOR_PASTE } from '~/vue_shared/constants';
import markdownEditorEventHub from '~/vue_shared/components/markdown/eventhub';
import { updateText } from '~/lib/utils/text_markdown';
import SummarizeCodeChanges from 'ee/merge_requests/components/summarize_code_changes.vue';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';

jest.mock('~/lib/utils/text_markdown');
jest.mock('~/vue_shared/components/markdown/eventhub');
jest.mock('uuid', () => ({
  v4: () => 'uuidv4',
}));

Vue.use(VueApollo);

let wrapper;
let aiResponseSubscriptionHandler;
let aiActionMutationHandler;

const { bindInternalEventDocument } = useMockInternalEventsTracking();

function createComponent(props = {}) {
  aiResponseSubscriptionHandler = createMockSubscription();
  aiActionMutationHandler = jest.fn().mockResolvedValue({ data: { aiAction: { errors: [] } } });
  const mockApollo = createMockApollo([[aiActionMutation, aiActionMutationHandler]]);

  mockApollo.defaultClient.setRequestHandler(
    aiResponseSubscription,
    () => aiResponseSubscriptionHandler,
  );

  wrapper = mountExtended(SummarizeCodeChanges, {
    propsData: {
      ...props,
    },
    apolloProvider: mockApollo,
    provide: {
      projectId: '1',
      sourceBranch: 'test-source-branch',
      targetBranch: 'test-target-branch',
    },
  });
}

const findButton = () => wrapper.findComponentByTestId('summarize-button');

describe('Merge request summarize code changes', () => {
  beforeEach(() => {
    window.gon = { current_user_id: 1 };
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('calls apollo mutation on click', async () => {
    createComponent();

    findButton().trigger('click');

    await waitForPromises();

    expect(aiActionMutationHandler).toHaveBeenCalledWith({
      input: {
        summarizeNewMergeRequest: {
          resourceId: 'gid://gitlab/Project/1',
          sourceProjectId: '1',
          sourceBranch: 'test-source-branch',
          targetBranch: 'test-target-branch',
        },
        clientSubscriptionId: 'uuidv4',
      },
    });
  });

  it('sets button as loading on click', async () => {
    createComponent();

    findButton().trigger('click');

    await waitForPromises();

    expect(findButton().find('.gl-spinner').exists()).toBe(true);
  });

  describe('when textarea exists', () => {
    beforeEach(() => {
      setHTMLFixture('<textarea class="js-gfm-input"></textarea>');
    });

    it('calls insertMarkdownText after subscription receives data', async () => {
      createComponent();

      await findButton().trigger('click');

      aiResponseSubscriptionHandler.next({
        data: {
          aiCompletionResponse: {
            id: 1,
            requestId: 1,
            content: 'AI generated content',
            errors: [],
            role: '',
            timestamp: '',
            type: '',
            chunkId: '',
            extras: {
              sources: [],
            },
            threadId: null,
          },
        },
      });

      await waitForPromises();

      expect(updateText).toHaveBeenCalledWith({
        textArea: document.querySelector('.js-gfm-input'),
        tag: 'AI generated content',
        cursorOffset: 0,
        wrap: false,
      });
    });
  });

  describe('when textarea does not exists', () => {
    beforeEach(() => {
      setHTMLFixture('<div class="js-gfm-input"></div>');
    });

    it('calls insertMarkdownText after subscription receives data', async () => {
      createComponent();

      await findButton().trigger('click');

      aiResponseSubscriptionHandler.next({
        data: {
          aiCompletionResponse: {
            id: 1,
            requestId: 1,
            content: 'AI generated content',
            errors: [],
            role: '',
            timestamp: '',
            type: '',
            chunkId: '',
            extras: {
              sources: [],
            },
            threadId: null,
          },
        },
      });

      await waitForPromises();

      expect(markdownEditorEventHub.$emit).toHaveBeenCalledWith(
        CONTENT_EDITOR_PASTE,
        'AI generated content',
      );
    });
  });

  describe('with tracking', () => {
    it('tracks button render and click', () => {
      createComponent();

      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith('render_summarize_code_changes', {}, undefined);

      findButton().trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith('click_summarize_code_changes', {}, undefined);
    });
  });

  describe('when disabled reason is set', () => {
    const disabledReason = 'No changes between source and target branches';

    beforeEach(() => {
      createComponent({
        disabledReason,
      });
    });

    it('disables the button', () => {
      expect(findButton().props('disabled')).toBe(true);
    });

    it('sets the tooltip', () => {
      expect(wrapper.attributes('title')).toEqual(disabledReason);
    });
  });

  describe('when disabled reason is not set', () => {
    it('does not set the tooltip', () => {
      createComponent();
      expect(wrapper.attributes('title')).toBeUndefined();
    });
  });
});
