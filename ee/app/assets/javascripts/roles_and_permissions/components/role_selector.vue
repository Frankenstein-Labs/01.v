<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { initialSelectedRole, roleDropdownItems } from 'ee/members/utils';

export default {
  name: 'RoleSelectorEE',
  components: {
    GlCollapsibleListbox,
  },
  inject: {
    standardRoles: {
      type: Object,
      required: true,
    },
    currentStandardRole: {
      type: Number,
      required: false,
      default: null,
    },
    customRoles: {
      type: Array,
      required: false,
      default: () => [],
    },
    currentCustomRoleId: {
      type: Number,
      required: false,
      default: null,
    },
  },
  emits: ['on-select'],
  data() {
    return {
      selectedRole: null,
      accessLevelOptions: roleDropdownItems({
        validRoles: this.standardRoles,
        customRoles: this.customRoles,
      }),
    };
  },
  computed: {
    selectedItem() {
      return this.accessLevelOptions.flatten.find(({ value }) => value === this.selectedRole);
    },
    toggleText() {
      return this.selectedRole ? this.selectedItem.text : s__('MemberRole|Select a role');
    },
  },
  watch: {
    accessLevelOptions: {
      immediate: true,
      handler(options) {
        const accessLevel = {
          integerValue: this.currentStandardRole,
          memberRoleId: this.currentCustomRoleId,
        };
        this.selectedRole = initialSelectedRole(options.flatten, { accessLevel })?.value;
      },
    },
  },
  methods: {
    onSelect(role) {
      this.selectedRole = role;
      const { accessLevel, memberRoleId } = this.selectedItem;

      this.$emit('on-select', {
        selectedStandardRoleValue: accessLevel,
        selectedCustomRoleValue: memberRoleId,
      });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :selected="selectedRole"
    block
    :items="accessLevelOptions.formatted"
    :toggle-text="toggleText"
    @select="onSelect"
  />
</template>
