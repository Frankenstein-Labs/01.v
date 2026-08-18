import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoQuestionNote from 'ee/work_items/components/notes/duo_question_note.vue';
import createNoteMutation from '~/work_items/graphql/notes/create_work_item_note.mutation.graphql';
import toggleResolveDiscussionMutation from '~/work_items/graphql/notes/toggle_work_item_note_resolve_discussion.mutation.graphql';
import {
  createWorkItemNoteResponse,
  mockToggleResolveDiscussionResponse,
} from 'jest/work_items/mock_data';

Vue.use(VueApollo);

const fenced = (payload) => `Which cutover approach should we use?

\`\`\`json:duo-question
${JSON.stringify(payload)}
\`\`\``;

// Most cases vary only the options of a closed question.
const closedBody = (options) => fenced({ type: 'closed', question: 'Which?', options });

const CLOSED_QUESTION = closedBody([
  { id: 'hard_removal', label: 'Hard removal', description: 'One patch.' },
  { id: 'staged', label: 'Staged deprecation', recommended: true },
]);

const WORK_ITEM_ID = 'gid://gitlab/WorkItem/1';
const DISCUSSION_ID = 'gid://gitlab/Discussion/abc';

describe('DuoQuestionNote', () => {
  let wrapper;
  let createNoteHandler;
  let resolveHandler;

  const createComponent = ({
    body = CLOSED_QUESTION,
    replies = [],
    isDiscussionResolved = false,
    duoWorkplanAsyncFlow = true,
  } = {}) => {
    createNoteHandler = jest.fn().mockResolvedValue(createWorkItemNoteResponse());
    resolveHandler = jest.fn().mockResolvedValue(mockToggleResolveDiscussionResponse);

    wrapper = shallowMountExtended(DuoQuestionNote, {
      apolloProvider: createMockApollo([
        [createNoteMutation, createNoteHandler],
        [toggleResolveDiscussionMutation, resolveHandler],
      ]),
      propsData: {
        note: { body, internal: false },
        workItemId: WORK_ITEM_ID,
        discussionId: DISCUSSION_ID,
        replies,
        isDiscussionResolved,
      },
      provide: { glFeatures: { duoWorkplanAsyncFlow } },
    });
  };

  const findCard = () => wrapper.findByTestId('duo-question-note');
  const findOptions = () => wrapper.findAllByTestId('duo-question-option');
  const findAnswer = () => wrapper.findByTestId('duo-answer');
  const answerText = () => (findAnswer().exists() ? findAnswer().text() : null);
  const asReplies = (bodies) => bodies.map((body) => ({ body }));
  const chooseOption = async (index) => {
    await findOptions().at(index).trigger('click');
    await waitForPromises();
  };

  describe('when a closed question is present', () => {
    beforeEach(() => createComponent());

    it('renders one control per option, labelled', () => {
      expect(findOptions()).toHaveLength(2);
      expect(findOptions().at(0).text()).toContain('Hard removal');
      expect(findOptions().at(0).text()).toContain('One patch.');
      expect(findOptions().at(1).text()).toContain('Staged deprecation');
    });

    it('badges only the option the agent recommends', () => {
      expect(findOptions().at(0).findComponent(GlBadge).exists()).toBe(false);
      expect(findOptions().at(1).findComponent(GlBadge).text()).toBe('Recommended');
    });

    it('renders no answer until one is chosen', () => {
      expect(findAnswer().exists()).toBe(false);
    });

    // The payload is model-authored, so nothing from it may reach the DOM as
    // markup. Guards against a future change reaching for v-html to get formatting.
    it('renders a label and description as text, never as markup', () => {
      createComponent({
        body: closedBody([
          {
            id: 'a',
            label: '<img src=x onerror=alert(1)>',
            description: '<script>alert(2)</script>',
          },
        ]),
      });
      const row = findOptions().at(0);

      expect(row.text()).toContain('<img src=x onerror=alert(1)>');
      expect(row.text()).toContain('<script>alert(2)</script>');
      expect(row.find('img').exists()).toBe(false);
      expect(row.find('script').exists()).toBe(false);
    });
  });

  describe('when nothing is renderable', () => {
    it.each`
      scenario                                            | props
      ${'the async flow flag is off'}                     | ${{ duoWorkplanAsyncFlow: false }}
      ${'the parser finds no question'}                   | ${{ body: 'Just an ordinary comment.' }}
      ${'the parser rejects the payload'}                 | ${{ body: '```json:duo-question\n{not json\n```' }}
      ${'the question is open, so nothing can be picked'} | ${{ body: fenced({ type: 'open', question: 'How many users?' }) }}
      ${'the question accepts several answers'}           | ${{ body: fenced({ type: 'closed', question: 'Which apply?', multiple: true, options: [{ id: 'a', label: 'A' }] }) }}
    `('renders nothing when $scenario', ({ props }) => {
      createComponent(props);

      expect(findCard().exists()).toBe(false);
    });
  });

  describe('when an option is chosen', () => {
    beforeEach(async () => {
      createComponent();
      await chooseOption(1);
    });

    it('posts the label as a reply, with the id recorded for later runs', () => {
      expect(createNoteHandler).toHaveBeenCalledWith({
        input: {
          noteableId: WORK_ITEM_ID,
          discussionId: DISCUSSION_ID,
          body: 'Staged deprecation\n\n<!-- duo-answer: staged -->',
          internal: false,
        },
      });
    });

    it('resolves the thread, which is what lets the flow resume', () => {
      expect(resolveHandler).toHaveBeenCalledWith({ id: DISCUSSION_ID, resolve: true });
    });

    it('replaces the options with the chosen answer', () => {
      expect(findOptions()).toHaveLength(0);
      expect(findAnswer().text()).toContain('Staged deprecation');
    });
  });

  describe('when the thread already carries an answer', () => {
    // A reload has no component state to fall back on, so the answer has to come
    // back out of the reply that carries it.
    it.each`
      scenario                       | markerId          | answer            | optionCount
      ${'matches an offered option'} | ${'hard_removal'} | ${'Hard removal'} | ${0}
      ${'matches no offered option'} | ${'nope'}         | ${null}           | ${2}
    `('when the marker $scenario', ({ markerId, answer, optionCount }) => {
      createComponent({
        replies: asReplies([`some reply\n\n<!-- duo-answer: ${markerId} -->`]),
        isDiscussionResolved: true,
      });

      expect(answerText()).toBe(answer);
      expect(findOptions()).toHaveLength(optionCount);
    });

    // Threads collect ordinary conversation too, and a peer quoting an earlier
    // answer must not read as a fresh one.
    it.each`
      scenario                            | replies
      ${'discussion precedes the answer'} | ${['What are the trade-offs?', 'Hard removal\n\n<!-- duo-answer: hard_removal -->']}
      ${'discussion follows the answer'}  | ${['Hard removal\n\n<!-- duo-answer: hard_removal -->', 'Agreed.']}
      ${'a peer quotes another option'}   | ${['Hard removal\n\n<!-- duo-answer: hard_removal -->', '> <!-- duo-answer: staged -->\n\nI prefer this.']}
    `('still shows the chosen option when $scenario', ({ replies }) => {
      createComponent({ replies: asReplies(replies), isDiscussionResolved: true });

      expect(answerText()).toBe('Hard removal');
    });

    it('prefers the most recent answer when the thread carries more than one', () => {
      createComponent({
        replies: asReplies([
          'Hard removal\n\n<!-- duo-answer: hard_removal -->',
          'Staged deprecation\n\n<!-- duo-answer: staged -->',
        ]),
        isDiscussionResolved: true,
      });

      expect(answerText()).toBe('Staged deprecation');
    });

    it('does not resolve an already-resolved thread a second time', async () => {
      createComponent({ isDiscussionResolved: true });
      await chooseOption(0);

      expect(createNoteHandler).toHaveBeenCalled();
      expect(resolveHandler).not.toHaveBeenCalled();
    });
  });

  describe('when the answer posts but the thread will not resolve', () => {
    beforeEach(async () => {
      createComponent();
      resolveHandler.mockRejectedValueOnce(new Error('nope'));
      await chooseOption(0);
    });

    it('keeps the answer, since the reply was posted', () => {
      expect(answerText()).toBe('Hard removal');
    });

    it('says the thread is unresolved rather than reporting a failed answer', () => {
      expect(wrapper.emitted('error')).toEqual([
        [
          'Your answer was posted, but the thread could not be resolved. Resolve it manually so GitLab Duo can continue.',
        ],
      ]);
    });
  });

  describe('when posting the answer fails', () => {
    it.each`
      scenario                        | fail
      ${'the request rejects'}        | ${(handler) => handler.mockRejectedValueOnce(new Error('nope'))}
      ${'the payload carries errors'} | ${(handler) => handler.mockResolvedValueOnce(createWorkItemNoteResponse({ errors: ['Note cannot be created'] }))}
    `('leaves the question answerable when $scenario', async ({ fail }) => {
      createComponent();
      fail(createNoteHandler);
      await chooseOption(0);

      expect(wrapper.emitted('error')).toHaveLength(1);
      expect(findOptions()).toHaveLength(2);
      expect(findAnswer().exists()).toBe(false);
      // No reply was posted, so resolving would settle a question nobody answered.
      expect(resolveHandler).not.toHaveBeenCalled();
    });
  });
});
