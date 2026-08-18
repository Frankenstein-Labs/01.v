<script>
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'NoCreditsBanner',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
  },
  computed: {
    bannerMessage() {
      return s__(
        'DuoAgentPlatform|No GitLab Credits remain for this billing period. %{linkStart}Learn more.%{linkEnd}',
      );
    },
    creditsPath() {
      return helpPagePath('subscriptions/gitlab_credits');
    },
  },
};
</script>
<template>
  <gl-alert variant="info" :dismissible="false" class="gl-rounded-none">
    <gl-sprintf :message="bannerMessage">
      <template #link="{ content }">
        <gl-link
          :href="creditsPath"
          target="_blank"
          class="!gl-no-underline hover:!gl-underline focus:!gl-underline active:!gl-underline"
        >
          {{ content }}
        </gl-link>
      </template>
    </gl-sprintf>
  </gl-alert>
</template>
