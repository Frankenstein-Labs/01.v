<script>
import { GlButton, GlEmptyState } from '@gitlab/ui';
import { SCANNER_TYPE } from 'ee/on_demand_scans/constants';

export default {
  name: 'DastProfilesDrawerEmptyState',
  components: {
    GlButton,
    GlEmptyState,
  },
  props: {
    profileType: {
      type: String,
      required: false,
      default: SCANNER_TYPE,
    },
  },
  emits: ['click'],
};
</script>

<template>
  <gl-empty-state
    :description="
      s__(
        'OnDemandScans|Start by creating a new profile. Profiles make it easy to save and reuse configuration details for GitLab’s security tools.',
      )
    "
  >
    <template #title>
      <h5 data-testid="empty-state-header">
        {{
          sprintf(s__('OnDemandScans|No %{profileType} profiles found for DAST'), { profileType })
        }}
      </h5>
    </template>
    <template #actions>
      <gl-button
        variant="confirm"
        category="primary"
        data-testid="new-empty-profile-button"
        @click="$emit('click')"
      >
        {{ sprintf(s__('OnDemandScans|New %{profileType} profile'), { profileType }) }}
      </gl-button>
    </template>
  </gl-empty-state>
</template>
