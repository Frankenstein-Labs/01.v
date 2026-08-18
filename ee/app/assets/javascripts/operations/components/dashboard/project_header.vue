<script>
import { GlButton, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';

export default {
  components: {
    ProjectAvatar,
    GlButton,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    project: {
      type: Object,
      required: true,
    },
  },
  emits: ['remove'],
  computed: {
    title() {
      return __('Remove card');
    },
  },
  methods: {
    onRemove() {
      this.$emit('remove', this.project.remove_path);
    },
  },
};
</script>

<template>
  <div class="-gl-my-3 -gl-mr-3 gl-flex gl-items-center gl-gap-3">
    <project-avatar
      :project-id="project.id"
      :project-name="project.name"
      :project-avatar-url="project.avatar_url"
      :size="24"
    />
    <div class="gl-line-clamp-1 gl-grow">
      <gl-link
        v-gl-tooltip
        class="gl-text-default"
        :href="project.web_url"
        :title="project.name_with_namespace"
        data-testid="project-link"
      >
        <span data-testid="project-namespace">{{ project.namespace.name }} /</span>
        <span class="gl-font-bold" data-testid="project-name"> {{ project.name }}</span>
      </gl-link>
    </div>
    <gl-button
      v-gl-tooltip
      category="tertiary"
      :title="title"
      :aria-label="title"
      icon="close"
      data-testid="remove-project-button"
      @click="onRemove"
    />
  </div>
</template>
