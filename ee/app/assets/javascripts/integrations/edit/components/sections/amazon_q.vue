<script>
import { mapState } from 'pinia';
import AmazonQApp from 'ee/amazon_q_settings/components/app.vue';
import { useIntegrationForm } from '~/integrations/edit/store';

export default {
  name: 'IntegrationSectionAmazonQ',
  components: {
    AmazonQApp,
  },
  computed: {
    ...mapState(useIntegrationForm, ['propsSource']),
    amazonQAppProps() {
      const amazonQProps = this.propsSource?.amazonQProps;

      if (!amazonQProps) {
        return null;
      }

      return {
        submitUrl: amazonQProps.amazonQSubmitUrl,
        disconnectUrl: amazonQProps.amazonQDisconnectUrl,
        identityProviderPayload: {
          instance_uid: amazonQProps.amazonQInstanceUid,
          aws_provider_url: amazonQProps.amazonQAwsProviderUrl,
          aws_audience: amazonQProps.amazonQAwsAudience,
        },
        amazonQSettings: {
          availability: amazonQProps.amazonQAvailability,
          roleArn: amazonQProps.amazonQRoleArn,
          ready: amazonQProps.amazonQReady,
          autoReviewEnabled: amazonQProps.amazonQAutoReviewEnabled,
        },
      };
    },
    shouldRender() {
      return Boolean(this.amazonQAppProps);
    },
  },
};
</script>

<template>
  <amazon-q-app v-if="shouldRender" v-bind="amazonQAppProps" />
</template>
