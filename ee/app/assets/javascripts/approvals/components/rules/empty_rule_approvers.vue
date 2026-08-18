<script>
import { GlPopover, GlLink } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'EmptyRuleApprovers',
  components: {
    GlPopover,
    GlLink,
    HelpIcon,
  },
  props: {
    eligibleApproversDocsPath: {
      type: String,
      required: false,
      default: '',
    },
    popoverId: {
      type: String,
      required: false,
      default: 'pop-approver',
    },
    popoverContainerId: {
      type: String,
      required: false,
      default: 'popovercontainer',
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center">
    <span>{{ __('Any eligible user') }}</span>
    <span :id="popoverContainerId" class="gl-ml-2 gl-inline-flex">
      <help-icon :id="popoverId" tabindex="0" :aria-label="__('help')" class="author-link" />
      <gl-popover :target="popoverId" :container="popoverContainerId" placement="top">
        <template #title>{{ __('Who can approve?') }}</template>
        <ul class="gl-pl-5">
          <li>
            {{ __('Any member with at least Developer permissions on the project.') }}
          </li>
          <li>{{ __('Members listed as CODEOWNERS of affected files.') }}</li>
          <li>
            {{
              __("Users or groups set as approvers in the project's or merge request's settings.")
            }}
          </li>
        </ul>
        <gl-link :href="eligibleApproversDocsPath" target="_blank">{{
          __('More information')
        }}</gl-link>
      </gl-popover>
    </span>
  </div>
</template>
