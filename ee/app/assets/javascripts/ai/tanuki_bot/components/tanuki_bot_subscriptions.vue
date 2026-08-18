<script>
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResponseStreamSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response_stream.subscription.graphql';
import { normalizeRender } from '~/lib/utils/vue3compat/normalize_render';

export default normalizeRender({
  props: {
    userId: {
      type: String,
      required: true,
    },
    clientSubscriptionId: {
      type: String,
      required: true,
    },
    cancelledRequestIds: {
      type: Array,
      default: () => [],
      required: false,
    },
    activeThreadId: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['error', 'message', 'message-stream', 'response-received'],
  methods: {
    isValidMessage(requestId, threadId) {
      // check if requestId was cancelled
      if (!requestId || this.cancelledRequestIds.includes(requestId)) {
        return false;
      }

      // check if the threadId is the same as the active thread
      // also accept messages when activeThreadId is not yet set (race condition on first message)
      return !threadId || !this.activeThreadId || threadId === this.activeThreadId;
    },
  },
  render() {
    return null;
  },
  apollo: {
    $subscribe: {
      aiCompletionResponse: {
        query: aiResponseSubscription,
        variables() {
          return {
            userId: this.userId,
            aiAction: 'CHAT',
          };
        },
        result({ data }) {
          const requestId = data?.aiCompletionResponse?.requestId;
          const threadId = data?.aiCompletionResponse?.threadId;

          if (this.isValidMessage(requestId, threadId)) {
            this.$emit('message', data.aiCompletionResponse);
          }
        },
        error(err) {
          this.$emit('error', err);
        },
      },
      aiCompletionResponseStream: {
        query: aiResponseStreamSubscription,
        variables() {
          return {
            userId: this.userId,
            clientSubscriptionId: this.clientSubscriptionId,
          };
        },
        result({ data }) {
          const requestId = data?.aiCompletionResponse?.requestId;
          const threadId = data?.aiCompletionResponse?.threadId;

          if (this.isValidMessage(requestId, threadId)) {
            this.$emit('message-stream', data.aiCompletionResponse);
          }

          if (data?.aiCompletionResponse?.chunkId) {
            this.$emit('response-received', requestId);
          }
        },
        error(err) {
          this.$emit('error', err);
        },
      },
    },
  },
});
</script>
