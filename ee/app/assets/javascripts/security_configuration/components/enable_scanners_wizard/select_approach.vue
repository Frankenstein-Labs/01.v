<script>
import { GlCard, GlIcon, GlFormRadioGroup, GlFormRadio, GlBadge, GlSprintf } from '@gitlab/ui';
import { APPROACH_QUICK, APPROACH_ADVANCED } from './constants';

export default {
  name: 'EnableScannersSelectApproach',
  components: {
    GlCard,
    GlIcon,
    GlFormRadioGroup,
    GlFormRadio,
    GlBadge,
    GlSprintf,
  },
  inject: ['enableScanners'],
  APPROACH_QUICK,
  APPROACH_ADVANCED,
  computed: {
    approach: {
      get() {
        return this.enableScanners.approach;
      },
      set(val) {
        this.enableScanners.approach = val;
      },
    },
  },
};
</script>
<template>
  <div>
    <gl-form-radio-group v-model="approach" class="gl-grid gl-grid-cols-2 gl-gap-5">
      <label class="gl-mb-0 gl-cursor-pointer gl-font-normal">
        <gl-card>
          <template #header>
            <div class="gl-flex gl-justify-between">
              <span>
                <gl-icon name="paper-airplane" />
                <strong>{{ s__('SecurityConfiguration|Quick setup') }}</strong>
              </span>
              <gl-form-radio :value="$options.APPROACH_QUICK" />
            </div>
          </template>
          <div class="gl-p-3">
            <strong class="gl-text-lg">
              {{ s__('SecurityConfiguration|Apply recommended defaults') }}
              <gl-badge>{{ s__('SecurityConfiguration|~3 min') }}</gl-badge>
            </strong>
            <p class="gl-text-subtle">
              {{
                s__(
                  "SecurityConfiguration|Get broad security coverage in minutes. We'll enable recommended scanners across your projects using GitLab's default profiles. You'll review all changes before anything is applied.",
                )
              }}
            </p>
            <gl-sprintf
              :message="
                s__(
                  'SecurityConfiguration|%{strongStart}Best for:%{strongEnd} Teams who want reliable protection with minimal setup',
                )
              "
            >
              <template #strong="{ content }"
                ><strong>{{ content }}</strong></template
              >
            </gl-sprintf>
          </div>
        </gl-card>
      </label>

      <label class="gl-mb-0 gl-cursor-pointer gl-font-normal">
        <gl-card>
          <template #header>
            <div class="gl-flex gl-justify-between">
              <span>
                <gl-icon name="settings" />
                <strong>{{ s__('SecurityConfiguration|Advanced setup') }}</strong>
              </span>
              <gl-form-radio :value="$options.APPROACH_ADVANCED" />
            </div>
          </template>
          <div class="gl-p-3">
            <strong class="gl-text-lg">
              {{ s__('SecurityConfiguration|Customize your configuration') }}
              <gl-badge>{{ s__('SecurityConfiguration|~9 min') }}</gl-badge>
            </strong>
            <p class="gl-text-subtle">
              {{
                s__(
                  "SecurityConfiguration|Choose exactly which projects and scanners to enable and which profiles to apply. We'll guide you through each step.",
                )
              }}
            </p>
            <gl-sprintf
              :message="
                s__(
                  'SecurityConfiguration|%{strongStart}Best for:%{strongEnd} Teams needing fine-grained control',
                )
              "
            >
              <template #strong="{ content }"
                ><strong>{{ content }}</strong></template
              >
            </gl-sprintf>
          </div>
        </gl-card>
      </label>
    </gl-form-radio-group>
    <p class="gl-m-5 gl-text-center gl-text-subtle">
      <gl-icon variant="info" name="information" />
      {{
        s__(
          'SecurityConfiguration|Other scanner types, including DAST, Container Scanning, and IaC, can be configured via security policies or at the project level.',
        )
      }}
    </p>
  </div>
</template>
