<script>
import { GlFormGroup, GlFormInput, GlFormTextarea } from '@gitlab/ui';

export default {
  name: 'DashboardSettingsForm',
  components: {
    GlFormGroup,
    GlFormInput,
    GlFormTextarea,
  },
  props: {
    value: {
      type: Object,
      required: true,
      validator: (value) => {
        return 'title' in value && 'description' in value;
      },
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input'],
  computed: {
    title: {
      get() {
        return this.value.title;
      },
      set(value) {
        this.$emit('input', {
          ...this.value,
          title: value,
        });
      },
    },
    description: {
      get() {
        return this.value.description;
      },
      set(value) {
        this.$emit('input', {
          ...this.value,
          description: value,
        });
      },
    },
  },
};
</script>

<template>
  <div>
    <gl-form-group :label="s__('AnalyticsDashboards|Dashboard title')" label-for="dashboard-title">
      <gl-form-input
        id="dashboard-title"
        v-model="title"
        :placeholder="s__('AnalyticsDashboards|Enter a title')"
        :disabled="isLoading"
      />
    </gl-form-group>
    <gl-form-group
      :label="s__('AnalyticsDashboards|Dashboard description')"
      label-for="dashboard-description"
    >
      <gl-form-textarea
        id="dashboard-description"
        v-model="description"
        :placeholder="s__('AnalyticsDashboards|Enter a description (optional)')"
        :disabled="isLoading"
      />
    </gl-form-group>
  </div>
</template>
