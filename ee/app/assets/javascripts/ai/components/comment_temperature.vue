<script>
import { v4 as uuidv4 } from 'uuid';
import { GlAlert, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import { InternalEvents } from '~/tracking';
import { convertToGraphQLId, isGid } from '~/graphql_shared/utils';
import { scrollToElement } from '~/lib/utils/scroll_utils';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { fetchPolicies } from '~/lib/graphql';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import { COMMENT_TEMPERATURE_EVENTS } from '../constants';

const CLIENT_SUBSCRIPTION_ID = uuidv4();
const trackingMixin = InternalEvents.mixin();

export default {
  name: 'AiCommentTemperature',
  components: {
    GlAlert,
    GlButton,
    GlSprintf,
    GlLink,
  },
  i18n: {
    title: __('Proceed with caution.'),
    warning: __(
      'We have detected that your message might be composed against %{linkStart}our guidelines%{linkEnd}. Please review our findings below:',
    ),
    commentAnyway: __('Comment anyway'),
    checkAgain: __('Updated. Check again'),
    leaveFeedback: __('Leave feedback'),
  },
  mixins: [trackingMixin],
  props: {
    userId: {
      type: Number,
      required: true,
    },
    itemType: {
      type: String,
      required: true,
    },
    itemId: {
      type: [Number, String],
      required: true,
      validator: (id) => {
        return typeof id === 'number' || isGid(id);
      },
    },
    value: {
      type: String,
      required: true,
    },
  },
  emits: ['save'],
  data() {
    return {
      isMeasuring: false,
      commentTemperatureIssues: [],
      subscribedToTemperatureUpdates: false,
    };
  },
  computed: {
    resourceGid() {
      return convertToGraphQLId(this.itemType, this.itemId);
    },
    userGid() {
      return convertToGraphQLId(TYPENAME_USER, this.userId);
    },
  },
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      aiCompletionResponse: {
        query: aiResponseSubscription,
        fetchPolicy: fetchPolicies.NO_CACHE,
        skip() {
          return !this.subscribedToTemperatureUpdates; // We manually start and stop the subscription.
        },
        variables() {
          return {
            resourceId: this.resourceGid,
            userId: this.userGid,
            clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
          };
        },
        result({ data: { aiCompletionResponse } }) {
          if (!aiCompletionResponse) {
            return;
          }
          const { content } = aiCompletionResponse;
          if (content) {
            let jsonResponse;
            const regex = /<temperature_rating>\s*(\{.*?\})\s*<\/temperature_rating>/s;
            const match = content.match(regex);

            try {
              if (match) {
                jsonResponse = JSON.parse(match[1]);
              } else {
                jsonResponse = JSON.parse(content);
              }
            } catch (e) {
              logError(e);
              createAlert({
                message: __(
                  'An error occured while parsing comment temperature. Please try again.',
                ),
              });
            }

            this.isMeasuring = false;
            if (jsonResponse) {
              const { rating, issues } = jsonResponse;
              const alreadyHadHighTemp = this.commentTemperatureIssues.length > 0;
              if (rating === 1) {
                this.save();
                return;
              }
              this.commentTemperatureIssues = issues;
              scrollToElement(this.$el);
              if (alreadyHadHighTemp) {
                this.trackEvent(COMMENT_TEMPERATURE_EVENTS.REPEATED_HIGH_TEMP);
              } else {
                this.trackEvent(COMMENT_TEMPERATURE_EVENTS.HIGH_TEMP);
              }
            }

            this.subscribedToTemperatureUpdates = false;
          }
        },
        error(e) {
          logError(e);
          createAlert({
            message: __(
              'An error occured when subscribing to the comment temperature updates. Please try again.',
            ),
          });
          this.subscribedToTemperatureUpdates = false;
        },
      },
    },
  },
  methods: {
    resetCommentTemperature() {
      this.commentTemperatureIssues = [];
      this.subscribedToTemperatureUpdates = false;
    },
    save(forced = false) {
      this.resetCommentTemperature();
      this.$emit('save');
      if (forced) {
        this.trackEvent(COMMENT_TEMPERATURE_EVENTS.FORCED_COMMENT);
      }
    },
    measureCommentTemperature() {
      this.isMeasuring = true;
      this.trackEvent(COMMENT_TEMPERATURE_EVENTS.MEASUREMENT_REQUESTED);
      this.$apollo
        .mutate({
          mutation: aiActionMutation,
          variables: {
            input: {
              measureCommentTemperature: {
                content: this.value,
                resourceId: this.resourceGid,
              },
              clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
            },
          },
        })
        .then(({ data: { aiAction } }) => {
          if (!aiAction.errors.length) {
            this.subscribedToTemperatureUpdates = true;
          }
        })
        .catch((e) => {
          logError(e);
          createAlert({
            message: __('Failed to measure the comment temperature. Please try again.'),
          });
        });
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="commentTemperatureIssues.length"
      variant="warning"
      class="gl-my-5"
      :dismissible="false"
      :title="$options.i18n.title"
      data-testid="comment-temperature-alert"
    >
      <p>
        <gl-sprintf :message="$options.i18n.warning">
          <template #link="{ content }">
            <gl-link href="https://handbook.gitlab.com/handbook/communication/" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <ul class="gl-mb-5 gl-pl-0">
        <li v-for="(issue, index) in commentTemperatureIssues" :key="index">{{ issue }}</li>
      </ul>
      <template #actions>
        <gl-button
          data-testid="bad-button"
          category="primary"
          variant="danger"
          class="gl-mr-3"
          @click="save(true)"
          >{{ $options.i18n.commentAnyway }}</gl-button
        >
        <gl-button
          data-testid="good-button"
          category="primary"
          variant="confirm"
          :loading="isMeasuring"
          @click="measureCommentTemperature"
          >{{ $options.i18n.checkAgain }}</gl-button
        >
      </template>
      <gl-button
        class="gl-float-right"
        category="tertiary"
        variant="confirm"
        href="https://gitlab.com/gitlab-org/gitlab/-/issues/511508"
        target="_blank"
        data-testid="feedback-link"
        >{{ $options.i18n.leaveFeedback }}</gl-button
      >
    </gl-alert>
  </div>
</template>
