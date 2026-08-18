<script>
import { GlAccordion, GlAccordionItem, GlSprintf } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';

export default {
  name: 'BranchPatternException',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlSprintf,
  },
  props: {
    branches: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    validBranches() {
      return this.branches.filter(
        (branch) => branch?.source?.pattern && (branch?.target?.pattern || branch?.target?.name),
      );
    },
    title() {
      return sprintf(s__('SecurityOrchestration|Branch exceptions (%{count})'), {
        count: this.validBranches.length,
      });
    },
    branchesFormattedList() {
      return this.validBranches.map((branch) =>
        sprintf(__('From %{codeStart}%{source}%{codeEnd} to: %{codeStart}%{target}%{codeEnd}'), {
          source: branch.source.pattern,
          target: branch.target.pattern || branch.target.name,
        }),
      );
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3">
    <gl-accordion-item :title="title">
      <ul class="gl-list-none gl-pl-4">
        <li
          v-for="branch in branchesFormattedList"
          :key="branch"
          class="gl-mb-3"
          data-testid="branch-item"
        >
          <gl-sprintf :message="branch">
            <template #code="{ content }">
              <code>{{ content }}</code>
            </template>
          </gl-sprintf>
        </li>
      </ul>
    </gl-accordion-item>
  </gl-accordion>
</template>
