<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';

export default {
  name: 'VulnerabilitiesPopover',
  components: {
    UserCalloutDismisser,
    GlIcon,
    GlPopover,
  },
  mixins: [glFeatureFlagsMixin()],
};
</script>

<template>
  <user-callout-dismisser ref="calloutDismisser" feature-name="focused_vulnerability_reporting">
    <template #default="{ dismiss, shouldShowCallout }">
      <div>
        <gl-icon id="vulnerabilities-info" name="information-o" class="gl-ml-2" variant="info" />
        <gl-popover
          :show="shouldShowCallout"
          :title="s__('Dependencies|Focused risk reporting')"
          placement="bottom"
          boundary="viewport"
          target="vulnerabilities-info"
          show-close-button
          data-testid="vulnerability-info-popover"
          @close-button-clicked="dismiss"
        >
          <p v-if="glFeatures.maliciousPackageDetection" class="gl-mb-0">
            {{
              s__(
                'Dependencies|Risk includes known vulnerabilities and malware packages currently detected in your project. Previously detected findings that are no longer present are excluded to keep risk assessments accurate.',
              )
            }}
          </p>
          <p v-else class="gl-mb-0">
            {{
              s__(
                'Dependencies|Risk includes known vulnerabilities currently detected in your project. Previously detected findings that are no longer present are excluded to keep risk assessments accurate.',
              )
            }}
          </p>
        </gl-popover>
      </div>
    </template>
  </user-callout-dismisser>
</template>
