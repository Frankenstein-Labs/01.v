<script>
import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { __ } from '~/locale';
import SafeHtml from '~/vue_shared/directives/safe_html';

export default {
  name: 'RepositorySizeLimitField',
  components: {
    GlFormGroup,
    GlFormInput,
  },
  directives: {
    SafeHtml,
  },
  i18n: {
    repositorySizeLimit: __('Repository size limit (MiB)'),
  },
  props: {
    value: {
      type: [Number, String],
      required: false,
      default: null,
    },
    helpText: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['input'],
};
</script>

<template>
  <gl-form-group
    :label="$options.i18n.repositorySizeLimit"
    label-for="project_repository_size_limit"
    class="gl-col-md-9"
  >
    <gl-form-input
      id="project_repository_size_limit"
      :value="value"
      type="number"
      name="project[repository_size_limit]"
      :min="0"
      data-testid="repository-size-limit-field"
      @input="$emit('input', $event)"
    />
    <template v-if="helpText" #description>
      <span v-safe-html="helpText"></span>
    </template>
  </gl-form-group>
</template>
