<script>
import { GlBanner } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { reportToSentry } from '~/ci/utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getTargetedMessageData from '../graphql/queries/get_targeted_message_data.query.graphql';

export default {
  name: 'TargetedMessageBanner',
  components: {
    GlBanner,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    namespaceFullPath: { type: String, required: true },
  },
  data: () => {
    return { targetedMessages: [] };
  },
  apollo: {
    targetedMessages: {
      query: getTargetedMessageData,
      skip() {
        return !this.glFeatures.targetedMessagesAdminUi;
      },
      variables() {
        return {
          fullPath: this.namespaceFullPath,
        };
      },
      update(data) {
        return data.namespace.targetedMessages;
      },
      error(error) {
        reportToSentry(this.$options.name, error);
      },
    },
  },
  computed: {
    hasMessages() {
      return this.targetedMessages.length > 0;
    },
  },
  buttonLink: `${PROMO_URL}/pricing/premium-promo`,
};
</script>

<template>
  <gl-banner
    v-if="hasMessages"
    :button-text="s__('TargetedMessages|Contact us')"
    :button-link="$options.buttonLink"
    :title="s__('TargetedMessages|Get access to Premium + GitLab Duo for $19 per user/month')"
    variant="promotion"
  >
    <p>
      {{
        s__(
          'TargetedMessages|For a limited time only, new customers can access all the benefits of Premium, plus advanced AI features for just $19. Contact our sales team today to take advantage while this offer lasts!',
        )
      }}
    </p>
  </gl-banner>
</template>
