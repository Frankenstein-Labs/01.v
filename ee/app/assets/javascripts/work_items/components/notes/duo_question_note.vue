<script>
import { GlBadge, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import createNoteMutation from '~/work_items/graphql/notes/create_work_item_note.mutation.graphql';
import toggleResolveDiscussionMutation from '~/work_items/graphql/notes/toggle_work_item_note_resolve_discussion.mutation.graphql';
import {
  buildDuoAnswer,
  parseDuoAnswer,
  parseDuoQuestion,
  PARSE_STATUS_OK,
  QUESTION_TYPE_CLOSED,
} from '../../utils/duo_question';

/**
 * Renders the clarifying question a workplan flow attached to its comment, so a
 * choice can be made in the discussion instead of by typing prose back at the agent.
 *
 * Answering posts the choice as a reply and resolves the thread. Resolving is the
 * part that matters: `Discussions::ResolveService` publishes
 * `WorkItems::DiscussionResolvedEvent`, and once every question the run posted is
 * resolved, `ContinueWorkplanAfterDiscussionsResolvedWorker` resumes the paused
 * workflow with the replies.
 */
export default {
  name: 'DuoQuestionNote',
  components: { GlBadge, GlIcon, GlLoadingIcon },
  mixins: [glFeatureFlagMixin()],
  props: {
    note: {
      type: Object,
      required: true,
    },
    workItemId: {
      type: String,
      required: true,
    },
    discussionId: {
      type: String,
      required: true,
    },
    replies: {
      type: Array,
      required: true,
    },
    isDiscussionResolved: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['error'],
  data() {
    return {
      submittingOptionId: null,
      answeredOptionId: null,
    };
  },
  computed: {
    duoWorkplanAsyncFlowEnabled() {
      return Boolean(this.glFeatures?.duoWorkplanAsyncFlow);
    },
    question() {
      if (!this.duoWorkplanAsyncFlowEnabled) return null;

      const result = parseDuoQuestion(this.note.body);
      if (result.status !== PARSE_STATUS_OK) return null;

      // An open question has nothing to pick from, so the prose above is already the
      // whole interaction. A multi-select one is deliberately skipped until
      // https://gitlab.com/gitlab-org/gitlab/-/issues/608852 adds checkboxes: rendered
      // as single-select, the first click would settle a question that wanted several
      // answers.
      const { question } = result;

      return question.type === QUESTION_TYPE_CLOSED && !question.multiple ? question : null;
    },
    options() {
      return this.question?.options ?? [];
    },
    // Survives a reload: the answer is recovered from the reply that carries it,
    // falling back to this session's choice before the reply reaches the cache.
    chosenOptionId() {
      if (this.answeredOptionId) return this.answeredOptionId;

      return this.replies.map((reply) => parseDuoAnswer(reply?.body)).findLast(Boolean);
    },
    chosenOption() {
      return this.options.find((option) => option.id === this.chosenOptionId) ?? null;
    },
    isSubmitting() {
      return Boolean(this.submittingOptionId);
    },
  },
  methods: {
    async answer(option) {
      this.submittingOptionId = option.id;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: createNoteMutation,
          variables: {
            input: {
              noteableId: this.workItemId,
              discussionId: this.discussionId || null,
              body: buildDuoAnswer(option),
              internal: this.note.internal,
            },
          },
        });

        if (data?.createNote?.errors?.length) {
          throw new Error(data.createNote.errors.join(', '));
        }

        this.answeredOptionId = option.id;
        await this.resolveThread();
      } catch (error) {
        this.$emit(
          'error',
          s__(
            'WorkItemDuoQuestion|Something went wrong while sending your answer. Please try again.',
          ),
        );
        Sentry.captureException(error);
      } finally {
        this.submittingOptionId = null;
      }
    },
    // A failure here must not read as the answer failing, since the reply is already
    // posted. It does need saying, though: resolving is what signals the question is
    // settled, so an unresolved thread leaves the run waiting.
    async resolveThread() {
      if (this.isDiscussionResolved) return;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: toggleResolveDiscussionMutation,
          variables: { id: this.discussionId, resolve: true },
        });

        const errors = data?.discussionToggleResolve?.errors;
        if (errors?.length) throw new Error(errors.join(', '));
      } catch (error) {
        this.$emit(
          'error',
          s__(
            'WorkItemDuoQuestion|Your answer was posted, but the thread could not be resolved. Resolve it manually so GitLab Duo can continue.',
          ),
        );
        Sentry.captureException(error);
      }
    },
  },
};
</script>

<template>
  <div v-if="question" class="gl-mt-3 gl-flex gl-flex-col gl-gap-3" data-testid="duo-question-note">
    <div
      v-if="chosenOption"
      class="gl-flex gl-items-center gl-gap-3 gl-rounded-lg gl-border-1 gl-border-solid gl-border-default gl-bg-subtle gl-px-4 gl-py-3 dark:gl-bg-neutral-800"
      data-testid="duo-answer"
    >
      <gl-icon name="check" :size="16" variant="success" class="gl-shrink-0" />
      <span>{{ chosenOption.label }}</span>
    </div>

    <template v-else>
      <!-- `type="button"` so a card inside the reply form never submits it. -->
      <button
        v-for="option in options"
        :key="option.id"
        type="button"
        class="gl-flex gl-w-full gl-items-start gl-gap-3 gl-rounded-lg gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-px-4 gl-py-3 gl-text-left gl-text-default hover:gl-bg-subtle dark:gl-bg-neutral-700 dark:hover:gl-bg-neutral-600"
        :disabled="isSubmitting"
        data-testid="duo-question-option"
        @click="answer(option)"
      >
        <gl-loading-icon v-if="submittingOptionId === option.id" size="sm" class="gl-shrink-0" />
        <span class="gl-grow">
          <span class="gl-block">{{ option.label }}</span>
          <span v-if="option.description" class="gl-mt-1 gl-block gl-text-sm gl-text-subtle">{{
            option.description
          }}</span>
        </span>
        <gl-badge v-if="option.recommended" variant="info" class="gl-mt-2 gl-shrink-0">{{
          s__('WorkItemDuoQuestion|Recommended')
        }}</gl-badge>
      </button>
    </template>
  </div>
</template>
