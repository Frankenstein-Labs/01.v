<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlIcon,
  GlLink,
  GlSkeletonLoader,
  GlToastMixin,
} from '@gitlab/ui';
import { fetchPolicies } from '~/lib/graphql';
import { __ } from '~/locale';
import { renderMarkdown } from '~/notes/utils';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { MAX_REQUEST_TIMEOUT } from 'ee/notes/constants';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import Tracking from '~/tracking';
import { concatStreamedChunks } from 'ee/ai/utils';

export default {
  name: 'AiSummary',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlIcon,
    GlLink,
    GlSkeletonLoader,
  },
  directives: { SafeHtml },
  mixins: [Tracking.mixin(), GlToastMixin],
  trackingLabel: 'ai_discussion_summary',
  inject: ['resourceGlobalId', 'summarizeClientSubscriptionId'],
  props: {
    aiLoading: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  emits: ['set-ai-loading'],
  data() {
    return {
      errorAlert: null,
      // eslint-disable-next-line vue/no-unused-properties -- Used by Apollo subscription auto-bind
      aiCompletionResponse: {},
      markdown: null,
      textForClipboard: null,
    };
  },
  computed: {
    subscriptionVariables() {
      return {
        userId: gon.current_user_id && convertToGraphQLId(TYPENAME_USER, gon.current_user_id),
        resourceId: this.resourceGlobalId,
        clientSubscriptionId: this.summarizeClientSubscriptionId,
      };
    },
  },
  watch: {
    aiLoading(isLoading) {
      if (isLoading) {
        this.markdown = null;
        this.summaryChunks = [];
      }
    },
  },
  beforeCreate() {
    this.summaryChunks = [];
  },
  mounted() {
    this.timeout = window.setTimeout(this.handleError, MAX_REQUEST_TIMEOUT);
  },
  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  },
  apollo: {
    $subscribe: {
      aiCompletionResponse: {
        query: aiResponseSubscription,
        // Apollo wants to write the subscription result to the cache, but we have none because we also
        // don't have a query. We only use this subscription as a notification.
        fetchPolicy: fetchPolicies.NO_CACHE,
        variables() {
          return this.subscriptionVariables;
        },
        error(error) {
          this.handleError(error);
        },
        async result({ data }) {
          if (!data?.aiCompletionResponse) {
            return;
          }

          if (data?.aiCompletionResponse?.errors?.length >= 1) {
            this.handleError({ message: data.aiCompletionResponse.errors[0] });
            return;
          }

          clearTimeout(this.timeout);
          if (this.aiLoading) {
            this.$emit('set-ai-loading', false);
          }

          if (data.aiCompletionResponse.chunkId) {
            this.summaryChunks[data.aiCompletionResponse.chunkId - 1] =
              data.aiCompletionResponse.content;

            this.markdown = renderMarkdown(concatStreamedChunks(this.summaryChunks));
          } else {
            this.markdown = data.aiCompletionResponse.contentHtml;
            this.textForClipboard = data.aiCompletionResponse.content;
          }
          await this.$nextTick();
          renderGFM(this.$refs.markdown);
        },
      },
    },
  },
  methods: {
    handleError(error) {
      const alertOptions = error ? { captureError: true, error } : {};
      this.errorAlert = createAlert({
        message: error ? error.message : __('Something went wrong'),
        ...alertOptions,
      });
      this.$emit('set-ai-loading', false);
    },
    dismissSummary() {
      this.markdown = null;
    },
    copyToClipboard() {
      this.$toast.show(__('Copied'));
    },
  },
  feedback: {
    link: 'https://gitlab.com/gitlab-org/gitlab/-/issues/407779',
  },
  i18n: {
    onlyVisibleToYou: __('Only visible to you'),
  },
  items: {
    copy: { text: __('Copy to clipboard') },
    remove: {
      text: __('Remove summary'),
      variant: 'danger',
    },
  },
};
</script>

<template>
  <div v-if="markdown || aiLoading" class="ai-summary-card gl-border gl-rounded-base gl-bg-subtle">
    <div class="gl-border-b gl-rounded-t-base gl-bg-default gl-px-5 gl-py-4">
      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-icon name="tanuki-ai" class="gl-text-purple-600" />
        <h5 class="gl-my-0">{{ __('AI-generated summary') }}</h5>
        <gl-disclosure-dropdown
          icon="ellipsis_v"
          category="tertiary"
          class="gl-ml-auto"
          :toggle-text="__('Actions')"
          text-sr-only
          data-testid="dropdown-actions"
          no-caret
          placement="bottom-end"
        >
          <gl-disclosure-dropdown-item
            :item="$options.items.copy"
            :data-clipboard-text="textForClipboard"
            data-testid="copy-ai-summary"
            :tracking-label="$options.trackingLabel"
            tracking-action="copy_summary"
            @action="copyToClipboard"
          />
          <gl-disclosure-dropdown-item
            :item="$options.items.remove"
            data-testid="remove-ai-summary"
            :tracking-label="$options.trackingLabel"
            tracking-action="remove_summary"
            @action="dismissSummary"
          />
        </gl-disclosure-dropdown>
      </div>
    </div>
    <div class="gl-px-5 gl-py-4">
      <gl-skeleton-loader v-if="aiLoading" :lines="5" />
      <div v-else>
        <div v-if="markdown" ref="markdown" v-safe-html="markdown" class="gl-mb-2"></div>

        <div class="gl-text-sm gl-text-subtle">
          <gl-icon name="eye-slash" class="gl-mr-2" :size="12" variant="subtle" />{{
            $options.i18n.onlyVisibleToYou
          }}
          &middot;
          <gl-link :href="$options.feedback.link" target="_blank" class="gl-text-sm">{{
            __('Leave feedback')
          }}</gl-link>
        </div>
      </div>
    </div>
  </div>
</template>
