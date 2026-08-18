import { ref } from 'vue';
import { GlButton } from '@gitlab/ui';
import DashboardDeleteModal from './dashboard_delete_modal.vue';

export default {
  component: DashboardDeleteModal,
  title: 'ee/vue_shared/components/dashboards_list/dashboard_delete_modal',
};

const Template = (args) => ({
  components: { DashboardDeleteModal, GlButton },
  setup() {
    const modalRef = ref(null);
    const showModal = () => {
      modalRef.value?.show();
    };
    return { args, modalRef, showModal };
  },
  template: `
    <div>
      <gl-button @click="showModal">Delete</gl-button>
      <dashboard-delete-modal ref="modalRef" v-bind="args" />
    </div>
  `,
});

export const Default = Template.bind({});
Default.args = {
  dashboardId: '1',
};
