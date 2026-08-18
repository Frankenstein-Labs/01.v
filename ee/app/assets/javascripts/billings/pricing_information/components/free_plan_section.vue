<script>
import { GlIcon } from '@gitlab/ui';

export default {
  name: 'FreePlanSection',
  components: {
    GlIcon,
  },
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3 gl-mb-6 gl-text-default">
      {{ s__('Billings|Your group is on the Free plan') }}
    </h3>

    <div class="gl-mb-6 gl-text-subtle">
      <p class="gl-mb-4 gl-text-md gl-font-normal">
        {{ s__('Billings|Features included:') }}
      </p>

      <div class="gl-text-sm">
        <div class="gl-list-style-none gl-p-0">
          <div class="gl-display-flex gl-align-items-start gl-mb-3">
            <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
            <span>{{ s__('Billings|Source Code Management & CI/CD') }}</span>
          </div>
          <div class="gl-display-flex gl-align-items-start gl-mb-3">
            <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
            <span>{{ s__('Billings|5 licensed users') }}</span>
          </div>
          <div class="gl-display-flex gl-align-items-start gl-mb-3">
            <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
            <span>{{ s__('Billings|400 compute minutes per month') }}</span>
          </div>
        </div>
      </div>
    </div>

    <p class="gl-text-sm gl-text-subtle">
      {{
        s__(
          'Billings|Upgrade to Premium to improve your experience and access new advanced AI features.',
        )
      }}
    </p>
  </div>
</template>
