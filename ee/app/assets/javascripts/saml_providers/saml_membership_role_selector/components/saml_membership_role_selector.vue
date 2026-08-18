<script>
import RoleSelector from 'ee/roles_and_permissions/components/role_selector.vue';

export default {
  components: {
    RoleSelector,
  },
  inject: ['currentStandardRole', 'currentCustomRoleId'],
  data() {
    return {
      selectedStandardRoleValue: this.currentStandardRole,
      selectedCustomRoleValue: this.currentCustomRoleId,
    };
  },
  methods: {
    async onSelect({ selectedStandardRoleValue, selectedCustomRoleValue }) {
      this.selectedStandardRoleValue = selectedStandardRoleValue;
      this.selectedCustomRoleValue = selectedCustomRoleValue;

      // This is necessary for `DirtySubmitForm` to detect changes in the form and toggle the submit button.
      await this.$nextTick();
      const event = new Event('input', { bubbles: true });

      this.$refs.standardRoleInput.dispatchEvent(event);
      this.$refs.customRoleInput.dispatchEvent(event);
    },
  },
};
</script>

<template>
  <div>
    <input
      ref="standardRoleInput"
      data-testid="selected-standard-role"
      type="hidden"
      name="saml_provider[default_membership_role]"
      :value="selectedStandardRoleValue"
    />
    <input
      ref="customRoleInput"
      data-testid="selected-custom-role"
      type="hidden"
      name="saml_provider[member_role_id]"
      :value="selectedCustomRoleValue"
    />
    <role-selector data-testid="default-membership-role-dropdown" @on-select="onSelect" />
  </div>
</template>
