<script>
import { GlFormGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import ProjectSelect from '~/vue_shared/components/entity_select/project_select.vue';

export default {
  name: 'DuoTemplateProjectSelector',
  i18n: {
    groupSectionTitle: s__('Duo|Customize code review'),
    instanceSectionTitle: s__('Duo|Customize code review for all groups in this instance'),
    sectionDescription: s__('Duo|Select a project to use for customizing code review.'),
  },
  components: {
    ProjectSelect,
    GlFormGroup,
  },
  inject: {
    rootNamespaceId: { default: null },
    isGroupSettings: { default: false },
  },
  props: {
    selectedProject: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: ['project-changed'],
  computed: {
    initialSelection() {
      if (!this.selectedProject) return null;

      return {
        value: String(this.selectedProject.id),
        text: this.selectedProject.nameWithNamespace || this.selectedProject.name,
      };
    },
    sectionTitle() {
      return this.isGroupSettings
        ? this.$options.i18n.groupSectionTitle
        : this.$options.i18n.instanceSectionTitle;
    },
  },
  methods: {
    onProjectSelected(item) {
      if (!item?.value) {
        this.$emit('project-changed', null);
        return;
      }

      // EntitySelector's watch fires with `initialSelectedItem` ({ value, text } only) as a
      // side effect when the user clicks reset - before the explicit @input({}) from onReset.
      // Real search results always include full API fields like `name`. Skip incomplete items
      // and let the subsequent @input({}) handle the clear.
      // Check `with incomplete items` in tests.
      if (!item.name && !item.name_with_namespace) return;

      this.$emit('project-changed', {
        id: parseInt(item.value, 10),
        name: item.name,
        nameWithNamespace: item.name_with_namespace,
        fullPath: item.full_path,
        avatarUrl: item.avatar_url,
      });
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group class="gl-mb-0">
      <h2 class="gl-heading-3 gl-mb-2 gl-mt-6">
        {{ sectionTitle }}
      </h2>

      <p class="gl-text-subtle">
        {{ $options.i18n.sectionDescription }}
      </p>

      <project-select
        :initial-selection="initialSelection"
        :group-id="rootNamespaceId"
        :label="__('Project')"
        class="gl-mt-3"
        input-name="duo_template_project_id"
        input-id="duo_template_project_id"
        @input="onProjectSelected"
      />
    </gl-form-group>
  </div>
</template>
