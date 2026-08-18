<script>
import { GlEmptyState, GlLink, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'EmptyState',
  i18n: {
    emptyStateButton: s__('CorpusManagement|New corpus'),
    emptyStateHeader: s__('CorpusManagement|Manage your fuzz testing corpus files'),
    emptyStateLink: __('Learn more'),
    emptyStateText: s__(
      'CorpusManagement|A corpus is used by fuzz testing to improve coverage. Corpus files can be manually created or auto-generated. %{linkStart}Learn more%{linkEnd}',
    ),
  },
  components: {
    GlEmptyState,
    GlLink,
    GlSprintf,
  },
  mixins: [glSlotsMixin],
  inject: ['emptyStateSvgPath', 'corpusHelpPath'],
};
</script>

<template>
  <gl-empty-state :title="$options.i18n.emptyStateHeader" :svg-path="emptyStateSvgPath">
    <template #description>
      <gl-sprintf :message="$options.i18n.emptyStateText">
        <template #link="{ content }">
          <gl-link :href="corpusHelpPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template v-if="glSlots().actions" #actions>
      <slot name="actions"></slot>
    </template>
  </gl-empty-state>
</template>
