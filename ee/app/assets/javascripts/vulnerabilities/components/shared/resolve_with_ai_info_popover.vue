<script>
import { GlAlert, GlPopover, GlSprintf, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'ResolveWithAiInfoPopover',
  components: {
    GlAlert,
    GlPopover,
    GlSprintf,
    GlLink,
  },
  props: {
    target: {
      type: String,
      required: true,
    },
    showPublicProjectWarning: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  confidentialMRHelpPagePath: helpPagePath('/user/application_security/vulnerabilities/_index', {
    anchor: 'vulnerability-resolution',
  }),
};
</script>

<template>
  <gl-popover :target="target">
    <p class="gl-mb-0">
      {{ s__('AI|Use GitLab Duo to generate a merge request with a suggested solution.') }}
    </p>
    <gl-alert
      v-if="showPublicProjectWarning"
      variant="warning"
      :dismissible="false"
      class="gl-mt-3 gl-text-sm"
    >
      <gl-sprintf
        :message="
          s__(
            'AI|Creating an MR from a public project will publicly expose the vulnerability and offered resolution. To create the MR privately, see %{linkStart} Resolving a vulnerability privately%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.confidentialMRHelpPagePath" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
  </gl-popover>
</template>
