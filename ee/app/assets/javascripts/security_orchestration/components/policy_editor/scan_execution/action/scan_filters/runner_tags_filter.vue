<script>
import { GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import RunnerTagsList from './runner_tags_list.vue';

export default {
  name: 'RunnerTagsFilter',
  i18n: {
    label: s__('ScanExecutionPolicy|Runner tags:'),
    selectedTagsInformation: s__(
      'ScanExecutionPolicy|A runner will be selected automatically from those available.',
    ),
  },
  components: {
    SectionLayout,
    HelpIcon,
    RunnerTagsList,
  },
  directives: {
    GlTooltip,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['error', 'input', 'remove'],
  methods: {
    handleSelection(values) {
      if (!values.length) {
        this.$emit('remove');
      } else {
        this.$emit('input', { tags: values });
      }
    },
  },
};
</script>

<template>
  <section-layout class="gl-w-full gl-bg-default" :show-remove-button="false">
    <template #selector>
      <label class="gl-mb-0 gl-mr-4" for="policy-tags" :title="$options.i18n.label">
        {{ $options.i18n.label }}
      </label>
    </template>
    <template #content>
      <div class="gl-flex gl-items-center">
        <runner-tags-list
          id="policy-tags"
          :selected-tags="selected"
          :namespace-path="namespacePath"
          :namespace-type="namespaceType"
          @error="$emit('error')"
          @input="handleSelection"
        />
        <help-icon v-gl-tooltip :title="$options.i18n.selectedTagsInformation" class="gl-ml-2" />
      </div>
    </template>
  </section-layout>
</template>
