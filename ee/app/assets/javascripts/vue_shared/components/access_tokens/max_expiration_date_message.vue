<script>
import { GlSprintf, GlLink } from '@gitlab/ui';

import { helpPagePath } from '~/helpers/help_page_helper';
import { formatDate } from '~/lib/utils/datetime_utility';

export default {
  name: 'MaxExpirationDateMessage',
  components: { GlSprintf, GlLink },
  props: {
    maxDate: {
      type: Date,
      required: false,
      default: () => null,
    },
  },
  computed: {
    formattedMaxDate() {
      return formatDate(this.maxDate, 'isoDate');
    },
  },
  methods: { helpPagePath },
};
</script>

<template>
  <span v-if="maxDate">
    <gl-sprintf
      :message="
        __(
          'An administrator has set the %{helpLinkStart}maximum expiration date%{helpLinkEnd} to %{maxDate}.',
        )
      "
    >
      <template #maxDate>{{ formattedMaxDate }}</template>
      <template #helpLink="{ content }"
        ><gl-link
          :href="
            /* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */
            helpPagePath('administration/settings/account_and_limit_settings', {
              anchor: 'limit-the-lifetime-of-access-tokens',
            }) /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */
          "
          target="_blank"
          >{{ content }}</gl-link
        ></template
      >
    </gl-sprintf>
  </span>
  <span v-else>
    {{ __('Clear the date to create access tokens without expiration.') }}
  </span>
</template>
