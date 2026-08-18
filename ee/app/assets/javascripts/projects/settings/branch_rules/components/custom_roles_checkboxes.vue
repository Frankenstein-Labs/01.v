<script>
import { GlFormCheckbox } from '@gitlab/ui';
import {
  accessLevelsConfig,
  ACCESS_LEVEL_CUSTOM_ROLE_INTEGER,
} from '~/projects/settings/branch_rules/components/constants';

export default {
  name: 'CustomRolesCheckboxes',
  accessLevelsConfig,
  ACCESS_LEVEL_CUSTOM_ROLE_INTEGER,
  sectionLabelId: 'custom-roles-section-label',
  components: {
    GlFormCheckbox,
  },
  props: {
    customRoles: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['change'],
  computed: {
    sectionLabel() {
      return this.$options.accessLevelsConfig[this.$options.ACCESS_LEVEL_CUSTOM_ROLE_INTEGER]
        .accessLevelLabel;
    },
  },
  methods: {
    isSelected(role) {
      return this.selectedIds.includes(role.id);
    },
    handleChange(role, checked) {
      const selected = checked
        ? [...this.selectedIds, role.id]
        : this.selectedIds.filter((selectedId) => selectedId !== role.id);

      this.$emit('change', selected);
    },
  },
};
</script>

<template>
  <div
    v-if="customRoles.length"
    role="group"
    :aria-labelledby="$options.sectionLabelId"
    data-testid="custom-roles-section"
  >
    <span
      :id="$options.sectionLabelId"
      class="gl-my-3 gl-block gl-font-bold"
      data-testid="custom-roles-section-label"
      >{{ sectionLabel }}</span
    >
    <gl-form-checkbox
      v-for="role in customRoles"
      :key="`member-role-${role.id}`"
      :checked="isSelected(role)"
      :data-testid="`custom-role-checkbox-${role.id}`"
      @change="handleChange(role, $event)"
    >
      {{ role.name }}
    </gl-form-checkbox>
  </div>
</template>
