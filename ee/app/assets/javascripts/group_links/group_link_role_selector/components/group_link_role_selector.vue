<script>
import RoleSelector from 'ee/roles_and_permissions/components/role_selector.vue';

export default {
  name: 'GroupLinkRoleSelector',
  components: {
    RoleSelector,
  },
  props: {
    baseAccessLevelInputName: {
      type: String,
      required: true,
    },
    memberRoleIdInputName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      selectedStandardRoleValue: null,
      selectedCustomRoleValue: null,
    };
  },
  methods: {
    onSelect({ selectedStandardRoleValue, selectedCustomRoleValue }) {
      this.selectedStandardRoleValue = selectedStandardRoleValue;
      this.selectedCustomRoleValue = selectedCustomRoleValue;
    },
  },
};
</script>

<template>
  <div>
    <input
      data-testid="selected-standard-role"
      type="hidden"
      :name="baseAccessLevelInputName"
      :value="selectedStandardRoleValue"
    />
    <input
      data-testid="selected-custom-role"
      type="hidden"
      :name="memberRoleIdInputName"
      :value="selectedCustomRoleValue"
    />
    <role-selector @on-select="onSelect" />
  </div>
</template>
