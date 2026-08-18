<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlTooltipDirective,
  GlLink,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';

export default {
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    ProjectAvatar,
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
  methods: {
    onRemove() {
      this.$emit('remove', this.project.remove_path);
    },
  },

  removeProjectText: s__('EnvironmentsDashboard|Remove'),
  moreActionsText: s__('EnvironmentsDashboard|More actions'),
  avatarSize: 24,
};
</script>

<template>
  <div
    class="gl-mb-5 gl-flex gl-items-center gl-justify-between gl-border-1 gl-border-default gl-pb-3 gl-text-subtle gl-border-b-solid"
  >
    <div class="gl-flex gl-items-center">
      <project-avatar
        :project-id="project.namespace.id"
        :project-name="project.namespace.name"
        :project-avatar-url="project.namespace.avatar_url"
        :size="$options.avatarSize"
        class="gl-mr-3"
      />
      <gl-link
        class="gl-mr-3 gl-text-subtle"
        :href="`/${project.namespace.full_path}`"
        data-testid="namespace-link"
      >
        {{ project.namespace.name }}
      </gl-link>

      <span class="gl-mr-3">&gt;</span>

      <project-avatar
        :project-id="project.id"
        :project-name="project.name"
        :project-avatar-url="project.avatar_url"
        :size="$options.avatarSize"
        class="gl-mr-3"
      />
      <gl-link class="gl-mr-3 gl-text-subtle" :href="project.web_url" data-testid="project-link">
        {{ project.name }}
      </gl-link>
    </div>
    <div class="gl-flex">
      <gl-disclosure-dropdown
        v-gl-tooltip
        :toggle-text="$options.moreActionsText"
        text-sr-only
        :title="$options.moreActionsText"
        icon="ellipsis_v"
        class="gl-text-subtle"
        toggle-class="gl-flex gl-items-center !gl-px-3 gl-bg-transparent !gl-shadow-none"
        no-caret
      >
        <gl-disclosure-dropdown-item
          data-testid="remove-project-button"
          variant="danger"
          @action="onRemove()"
        >
          <template #list-item>
            {{ $options.removeProjectText }}
          </template>
        </gl-disclosure-dropdown-item>
      </gl-disclosure-dropdown>
    </div>
  </div>
</template>
