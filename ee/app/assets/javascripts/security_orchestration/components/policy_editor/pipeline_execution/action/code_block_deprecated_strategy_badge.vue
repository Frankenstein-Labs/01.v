<script>
import { GlBadge, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';

export default {
  i18n: {
    text: __('Deprecated'),
    tooltip: s__(
      'ScanExecutionPolicy|%{boldStart}inject_ci%{boldEnd} strategy was deprecated. It was replaced by %{boldStart}inject_policy%{boldEnd} which enforces custom stages. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  name: 'CodeBlockDeprecatedStrategyBadge',
  components: {
    GlBadge,
    GlLink,
    GlSprintf,
    GlPopover,
  },

  INJECT_DEPRECATED_HELP_LINK: helpPagePath(
    'user/application_security/policies/pipeline_execution_policies',
    { anchor: 'inject_ci-deprecated' },
  ),
};
</script>

<template>
  <div>
    <gl-badge id="strategy-deprecated-badge" variant="info">
      {{ __('Deprecated') }}
    </gl-badge>
    <gl-popover
      container="strategy-selector-dropdown"
      boundary="viewport"
      target="strategy-deprecated-badge"
      placement="right"
    >
      <gl-sprintf :message="$options.i18n.tooltip">
        <template #bold="{ content }">
          <b>{{ content }}</b>
        </template>
        <template #link="{ content }">
          <gl-link :href="$options.INJECT_DEPRECATED_HELP_LINK" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-popover>
  </div>
</template>
