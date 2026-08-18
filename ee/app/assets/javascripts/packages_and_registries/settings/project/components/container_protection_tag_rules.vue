<script>
import { GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import CeContainerProtectionTagRules from '~/packages_and_registries/settings/project/components/container_protection_tag_rules.vue';

export default {
  name: 'ContainerProtectionTagRulesEE',
  components: {
    CeContainerProtectionTagRules,
    GlBadge,
  },
  methods: {
    getBadgeText({ immutable }) {
      return immutable ? s__('ContainerRegistry|immutable') : s__('ContainerRegistry|protected');
    },
  },
};
</script>

<template>
  <ce-container-protection-tag-rules>
    <template #description>
      {{
        s__(
          'ContainerRegistry|Set up rules to protect container image tags from unauthorized changes or make them permanently immutable. Protection rules are checked first, followed by immutable rules. You can add up to 5 protection rules per project.',
        )
      }}
    </template>

    <template #tag-badge="{ item }">
      <gl-badge data-testid="protection-type-badge">
        {{ getBadgeText(item) }}
      </gl-badge>
    </template>
  </ce-container-protection-tag-rules>
</template>
