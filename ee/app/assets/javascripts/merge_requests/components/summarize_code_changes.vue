<script>
import { v4 as uuidv4 } from 'uuid';
import { GlButton, GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { CONTENT_EDITOR_PASTE } from '~/vue_shared/constants';
import { updateText } from '~/lib/utils/text_markdown';
import { TYPENAME_PROJECT, TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import markdownEditorEventHub from '~/vue_shared/components/markdown/eventhub';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';

const CLIENT_SUBSCRIPTION_ID = uuidv4();

export default {
  name: 'SummarizeCodeChanges',
  components: {
    GlButton,
    GlBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['projectId', 'sourceBranch', 'targetBranch'],
  props: {
    disabledReason: {
      type: String,
      required: false,
      default: null,
    },
  },
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      aiCompletionResponse: {
        query: aiResponseSubscription,
        variables() {
          return {
            resourceId: this.resourceId,
            userId: this.userId,
            htmlResponse: false,
            clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
          };
        },
        result({ data: { aiCompletionResponse } }) {
          if (aiCompletionResponse) {
            const { content } = aiCompletionResponse;
            const textArea = document.querySelector('textarea.js-gfm-input');

            if (textArea) {
              updateText({
                textArea,
                tag: content,
                cursorOffset: 0,
                wrap: false,
              });
            } else {
              markdownEditorEventHub.$emit(CONTENT_EDITOR_PASTE, content);
            }

            this.loading = false;
          }
        },
      },
    },
  },
  data() {
    return {
      loading: false,
    };
  },
  computed: {
    resourceId() {
      return convertToGraphQLId(TYPENAME_PROJECT, this.projectId);
    },
    userId() {
      return convertToGraphQLId(TYPENAME_USER, gon.current_user_id);
    },
    disabled() {
      return Boolean(this.disabledReason);
    },
  },
  mounted() {
    this.trackEvent('render_summarize_code_changes');
  },
  methods: {
    onClick() {
      this.loading = true;
      this.trackEvent('click_summarize_code_changes');

      this.$apollo.mutate({
        mutation: aiActionMutation,
        variables: {
          input: {
            summarizeNewMergeRequest: {
              resourceId: this.resourceId,
              sourceProjectId: this.projectId,
              sourceBranch: this.sourceBranch,
              targetBranch: this.targetBranch,
            },
            clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
          },
        },
      });
    },
  },
};
</script>

<template>
  <span v-gl-tooltip :title="disabledReason">
    <gl-button
      icon="tanuki-ai"
      category="tertiary"
      size="small"
      :disabled="disabled"
      :loading="loading"
      data-testid="summarize-button"
      @click="onClick"
    >
      {{ __('Summarize code changes') }}
      <gl-badge variants="neutral" class="gl-ml-2">{{ __('Beta') }}</gl-badge>
    </gl-button>
  </span>
</template>
