<script>
import { GlFormCheckbox, GlIcon, GlPopover, GlBadge, GlSprintf } from '@gitlab/ui';
import { ACCESS_LEVELS_STRING_TO_INTEGER, ACCESS_LEVEL_LABELS } from '~/access_level/constants';

export default {
  name: 'PermissionCheckbox', // The name is needed so this component can recursively render itself.
  components: { GlFormCheckbox, GlIcon, GlPopover, GlBadge, GlSprintf },
  props: {
    permission: {
      type: Object,
      required: true,
    },
    baseAccessLevel: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['change'],
  computed: {
    baseRoleName() {
      const accessLevelInteger = ACCESS_LEVELS_STRING_TO_INTEGER[this.baseAccessLevel];
      return ACCESS_LEVEL_LABELS[accessLevelInteger];
    },
    hasChildPermissions() {
      return this.permission.children?.length > 0;
    },
  },
  // Classes for the vertical line to the left of nested permissions. It has the following behavior:
  // 1. Start with a full height vertical line.
  // 2. If it's the last checkbox, change the line to a backwards L and vertically align it with the checkbox.
  // 3. If it's the first checkbox, extend the line slightly higher so that it's closer to the parent checkbox.
  indentGuideClasses: [
    // Common style for full height line.
    'before:gl-content-[""]',
    'before:gl-absolute',
    'before:gl-border-l',
    'before:-gl-left-px',
    'before:!gl-border-2',
    'before:gl-top-0',
    'before:gl-bottom-0',
    // First checkbox style to make it extend slightly higher up.
    'first:before:-gl-top-2',
    // Last checkbox style to change it to a backwards L shape.
    'before:last:gl-border-b',
    'before:last:gl-w-3',
    'before:last:gl-mb-5',
    'before:last:gl-bottom-1',
  ],
};
</script>

<template>
  <li class="gl-pl-0">
    <gl-form-checkbox
      :disabled="permission.disabled"
      :checked="permission.checked"
      class="gl-mb-2 gl-ml-5 gl-inline-block"
      @change="$emit('change', permission)"
    >
      <span class="gl-text-default">{{ permission.name }}</span>
    </gl-form-checkbox>

    <gl-icon ref="description" name="information-o" class="gl-ml-1 gl-shrink-0 gl-cursor-pointer" />
    <gl-popover :target="() => $refs.description" triggers="focus" no-fade placement="auto">
      {{ permission.description }}
    </gl-popover>

    <gl-badge v-if="permission.disabled" class="gl-ml-3" variant="info">
      <gl-sprintf :message="s__('MemberRole|Added from %{role}')">
        <template #role>{{ baseRoleName }}</template>
      </gl-sprintf>
    </gl-badge>

    <ul v-if="hasChildPermissions" class="gl-list-none gl-pl-3">
      <permission-checkbox
        v-for="childPermission in permission.children"
        :key="childPermission.value"
        :permission="childPermission"
        :base-access-level="baseAccessLevel"
        class="gl-relative gl-ml-5"
        :class="$options.indentGuideClasses"
        @change="$emit('change', $event)"
      />
    </ul>
  </li>
</template>
