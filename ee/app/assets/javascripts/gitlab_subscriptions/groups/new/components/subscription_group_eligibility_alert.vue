<script>
import { GlAlert } from '@gitlab/ui';
import { ApolloError } from '@apollo/client';
import { s__, sprintf } from '~/locale';

export default {
  name: 'SubscriptionGroupEligibilityAlert',
  components: {
    GlAlert,
  },
  props: {
    error: {
      type: ApolloError,
      required: true,
    },
    planName: {
      type: String,
      required: true,
    },
  },
  computed: {
    title() {
      return sprintf(s__('SubscriptionGroupsNew|This group is not eligible for %{planName}'), {
        planName: this.planName,
      });
    },
  },
};
</script>
<template>
  <gl-alert variant="danger" :dismissible="false" class="gl-mb-5">
    <p class="gl-mb-3 gl-font-bold">{{ title }}</p>
    <p>
      {{ error.message }}
    </p>
  </gl-alert>
</template>
