<script>
import PoliciesList from './list/policies_list.vue';
import CreatePolicyWizard from './create/create_policy_wizard.vue';

export default {
  name: 'SecurityPoliciesApp',
  components: {
    PoliciesList,
    CreatePolicyWizard,
  },
  data() {
    return {
      currentView: 'list',
      editingPolicy: null,
    };
  },
  methods: {
    handleEdit(policy) {
      this.editingPolicy = policy;
      this.currentView = 'create';
    },
    handleCancel() {
      this.editingPolicy = null;
      this.currentView = 'list';
    },
    handleSubmit() {
      this.editingPolicy = null;
      this.currentView = 'list';
    },
  },
};
</script>

<template>
  <div>
    <policies-list
      v-if="currentView === 'list'"
      @create="currentView = 'create'"
      @edit="handleEdit"
    />
    <create-policy-wizard
      v-else-if="currentView === 'create'"
      :initial-policy="editingPolicy"
      @cancel="handleCancel"
      @submit="handleSubmit"
    />
  </div>
</template>
